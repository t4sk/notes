# Elliptic Curve Diffie-Hellman (ECDH)

Use to create a shared key without revealing what it is

```
* = EC scalar mul

Alice's private key = a
[a] = a*G

Bob's private key = b
[b] = b*G

# Public key exchange
      [a]
Alice --> Bob
      [b]
Alice <-- Bob

# Shared key calculation
Alice -> a*[b] = a*(b*G) = (ab)*G
Bob   -> b*[a] = b*(a*G) = (ba)*G

[s] = shared key = (ab)*G = (ba)*G
```
