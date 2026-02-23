val: public(uint256)

@deploy
def __init__(_val: uint256):
    self.val = _val


@external
def store(_val: uint256):
    self.val = _val


@external
def get() -> uint256:
    return self.val
