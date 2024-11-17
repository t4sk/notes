from collections import defaultdict
from lib import U32_MAX, U128_MAX, first_8_bits
from game_types import GameStatus, OutputRoot, VMStatus
from udt import Clock, Claim
from position import Position

ABSOLUTE_PRESTATE = "0"
MAX_GAME_DEPTH = 73
SPLIT_DEPTH = 30
MAX_CLOCK_DURATION = int(3.5 * 24 * 3600)
CLOCK_EXTENSION = 3 * 3600
CHALLENGE_PERIOD = 24 * 3600

class ClaimData:
    def __init__(self, **kwargs):
        self.parent_index = kwargs["parent_index"]
        self.countered_by = kwargs["countered_by"]
        self.claimant = kwargs["claimant"]
        self.bond = kwargs["bond"]
        self.claim = kwargs["claim"]
        self.position = kwargs["position"]
        self.clock = kwargs["clock"]

    def __repr__(self):
        return str(vars(self))

class ResolutionCheckpoint:
    def __init__(self, **kwargs):
        self.initial_checkpoint_complete = False
        self.subgame_index = 0
        self.leftmost_position = None
        self.countered_by = None

    def __repr__(self):
        return str(vars(self))

class FaultDisputeGame:
    def __init__(self):
        self.status = GameStatus.IN_PROGRESS
        self.l2_block_num_challenged = False
        self.l2_block_num_challenger = None
        self.claim_data = []
        # claim hash => bool
        self.claims = defaultdict(bool)
        # challenge index => [claim_data indexes]
        self.subgames = defaultdict(list)
        self.status = GameStatus.IN_PROGRESS
        # clain idex => bool
        self.resolved_subgames = defaultdict(bool)
        # claim index => ResolutionCheckpoint
        self.resolution_checkpoints = defaultdict(ResolutionCheckpoint)
        self.starting_output_root = None

    def initialize(self, **kwargs):
        self.starting_output_root = OutputRoot(
            root = kwargs["l2_root"],
            l2_block_num = kwargs["l2_block_num"]
        )
        self.claim_data.append(
            ClaimData(
                parent_index = U32_MAX,
                countered_by = None,
                claimant = kwargs["game_creator"],
                bond = kwargs["bond"],
                claim = kwargs["root_claim"],
                position = 1,
                clock = Clock.wrap(0, kwargs["block_timestamp"])
            )
        )

    def step(self, claim_idx, is_attack, state_data, proof, **kwargs):
        assert self.status == GameStatus.IN_PROGRESS

        parent = self.claim_data[claim_idx]
        parent_pos = parent.position
        step_pos = Position.move(parent_pos, is_attack)

        assert Position.depth(step_pos) == MAX_GAME_DEPTH + 1

        pre_state_claim = None
        post_state = None
        if is_attack:
            if (Position.index_at_depth(step_pos) % (1 << MAX_GAME_DEPTH - SPLIT_DEPTH)) == 0:
                pre_state_claim = ABSOLUTE_PRESTATE
            else:
                pre_state_claim = self._find_trace_ancestor(
                    parent_pos + 1,
                    parent.parent_index,
                    False
                ).claim
            post_state = parent
        else:
            pre_state_claim = parent.claim
            post_state = self._find_trace_ancestor(
                parent_pos + 1,
                parent.parent_index,
                False
            ).claim

        assert keccak256(state_data) << 8 == pre_state_claim << 8

        # TODO:

    def move(self, disputed, challenge_idx, claim, is_attack, **kwargs):
        assert self.status == GameStatus.IN_PROGRESS

        parent = self.claim_data[challenge_idx]
        assert parent.claim == disputed
        
        parent_pos = parent.position
        next_pos = Position.move(parent_pos, is_attack)
        next_pos_depth = Position.depth(next_pos)

        if (challenge_idx == 0 or next_pos_depth == SPLIT_DEPTH + 2) and not is_attack:
            raise "cannot defend root claim"

        if self.l2_block_num_challenged and challenge_idx == 0:
            raise "L2 block num challenged"

        if next_pos_depth > MAX_GAME_DEPTH:
            raise "game depth exceeded"

        if next_pos_depth == SPLIT_DEPTH + 1:
            self._verify_exec_bisection_root(claim, challenge_idx, parent_pos, is_attack)

        if self.get_required_bond(next_pos) != kwargs["msg_value"]:
            raise "incorrect bond"

        next_duration = self.get_challenger_duration(challenge_idx, **kwargs)
        if next_duration >= MAX_CLOCK_DURATION:
            raise "clock time exceeded"

        actual_ext = 0
        if next_pos_depth == MAX_GAME_DEPTH - 1:
            actual_ext = CLOCK_EXTENSION + CHALLENGE_PERIOD
        elif next_pos_depth == SPLIT_DEPTH - 1:
            actual_ext = CLOCK_EXTENSION * 2
        else:
            actual_ext = CLOCK_EXTENSION

        if next_duration > MAX_CLOCK_DURATION - actual_ext:
            next_duration = MAX_CLOCK_DURATION - actual_ext

        next_clock = Clock.wrap(next_duration, kwargs["block_timestamp"])

        claim_hash = Claim.hash_claim_pos(claim, next_pos, challenge_idx)
        if self.claims[claim_hash]:
            raise "claim already exists"
        self.claims[claim_hash] = True

        self.claim_data.append(
            ClaimData(
                parent_index = challenge_idx,
                countered_by = None,
                claimant = kwargs["msg_sender"],
                bond = kwargs["msg_value"],
                claim = claim,
                position = next_pos,
                clock = next_clock
            )
        )

        self.subgames[challenge_idx].append(len(self.claim_data) - 1)

    def challenge_root_l2_block(self, output_root_proof, header_rlp, **kwargs):
        assert self.status != GameStatus.IN_PROGRESS
        assert not self.l2_block_num_challenged
        assert Hashing.hash_output_root_proof(output_root_proof) == self.root_claim

        # TODO:
        self.l2_block_num_challenger = kwargs["msg_sender"]
        self.l2_block_num_challenged = True

    def resolve(self, **kwargs):
        assert self.status == GameStatus.IN_PROGRESS
        assert self.resolved_subgames[0]
        
        if self.claim_data[0].countered_by == None:
            self.status = GameStatus.DEFENDER_WINS 
        else:
            self.status = GameStatus.CHALLENGER_WINS
        # skip - anchor state registry
    
    def resolve_claim(self, claim_idx, num_to_resolve, **kwargs):
        assert self.status == GameStatus.IN_PROGRESS
        subgame_root_claim = self.claim_data[claim_idx]
        challenge_dur = self.get_challenger_duration(claim_idx, **kwargs)

        print(challenge_dur, MAX_CLOCK_DURATION)
        assert challenge_dur >= MAX_CLOCK_DURATION
        assert not self.resolved_subgames[claim_idx]
        
        challenge_indexes = self.subgames[claim_idx]
        challenge_len = len(challenge_indexes)

        if challenge_len == 0 and claim_idx != 0:
            countered_by = subgame_root_claim.countered_by
            recipient = subgame_root_claim.claimant if countered_by == None else countered_by
            # skip - distribute bond
            self.resolved_subgames[claim_idx] = True
            return
            
        checkpoint = self.resolution_checkpoints[claim_idx]

        if not checkpoint.initial_checkpoint_complete:
            checkpoint.leftmost_position = U128_MAX
            checkpoint.initial_checkpoint_complete = True
            if num_to_resolve == 0:
                num_to_resolve = challenge_len

        last_to_resolve = checkpoint.subgame_index + num_to_resolve
        final_cursor = min(last_to_resolve, challenge_len)
        for i in range(checkpoint.subgame_index, final_cursor):
            challenge_idx = challenge_indexes[i]
            assert self.resolved_subgames[challenge_idx]

            claim = self.claim_data[challenge_idx]
            if claim.countered_by is None and checkpoint.leftmost_position > claim.position:
                checkpoint.countered_by = claim.claimant
                checkpoint.leftmost_position = claim.position

        checkpoint.subgame_index = final_cursor
        self.resolution_checkpoints[claim_idx] = checkpoint

        if checkpoint.subgame_index == challenge_len:
            countered = checkpoint.countered_by
            self.resolved_subgames[claim_idx] = True
            
            if claim_idx == 0 and self.l2_block_num_challenged:
                challenger = self.l2_block_num_challenger
                # skip distribute bond
                subgame_root_claim.countered_by = challenger
            else:
                # skip distribute bond
                subgame_root_claim.countered_by = countered
    
    def get_required_bond(self, pos):
        # TODO
        return 0

    def get_challenger_duration(self, claim_idx, **kwargs):
        assert self.status == GameStatus.IN_PROGRESS

        subgame_root_claim = self.claim_data[claim_idx]

        parent_clock = 0
        if subgame_root_claim.parent_index != U32_MAX:
            parent_clock = self.claim_data[subgame_root_claim.parent_index].clock

        challenge_duration = Clock.duration(parent_clock) + kwargs["block_timestamp"] - Clock.timestamp(subgame_root_claim.clock)

        print("HERE", Clock.duration(parent_clock), kwargs["block_timestamp"], Clock.timestamp(subgame_root_claim.clock))
        
        return min(int(challenge_duration), MAX_CLOCK_DURATION)

    def _verify_exec_bisection_root(
        self, root_claim, parent_idx, parent_pos, is_attack, **kwargs
    ):
        disputed_leaf_pos = parent_pos + 1
        disputed = self._find_trace_ancestor(disputed_leaf_pos, parent_index, True)

        vm_status = VMStatus(first_8_bits(root_claim))

        if is_attack or Position.depth(disputed.position) % 2 == SPLIT_DEPTH % 2:
            if not vm_status in [VMStatus.INVALID, VMStatus.PANIC]:
                raise "unexpected root claim"
        elif vm_status != VMStatus.VALID:
            raise "unexpected root claim"

    def _find_trace_ancestor(self, pos, start_idx, is_global):
        trace_ancestor_pos = Position.trace_ancestor(pos) if is_global else Position.trace_ancestor_bounded(pos, SPLIT_DEPTH)

        ancestor = self.claim_data[start_idx]
        while ancestor.position != trace_ancestor_pos:
            ancestor = self.claim_data[ancestor.parent_index]
        return ancestor































