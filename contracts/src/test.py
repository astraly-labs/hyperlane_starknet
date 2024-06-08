from Crypto.Hash import keccak
k= keccak.new(digest_bits=256)
k.update(bytes.fromhex('68656c6c6f0000000000000000000000'))
print(k.hexdigest())