import graphviz

class Node:
    def __init__(self, val):
        self.val = val
        self.left = None
        self.right = None

    def __str__(self):
        left = None
        if self.left:
            left = self.left.val

        right = None
        if self.right:
            right = self.right.val

        return f'Node(val = {self.val}, left = {left}, right = {right})'

def insert(root, val):
    assert root != None

    q = [root]
    while len(q) > 0:
        node = q.pop(0)

        if node.left is None:
            node.left = Node(val)
            return
        else:
            q.append(node.left)

        if node.right is None:
            node.right = Node(val)
            return
        else:
            q.append(node.right)

def walk(root, dot):
    if root:
        dot.node(str(root.val), label=str(root.val))
        if root.left:
            dot.edge(str(root.val), str(root.left.val))
        if root.right:
            dot.edge(str(root.val), str(root.right.val))
        walk(root.left, dot)
        walk(root.right, dot)

def vis(root):
    dot = graphviz.Graph()
    walk(root, dot)
    dot.render(view=True)