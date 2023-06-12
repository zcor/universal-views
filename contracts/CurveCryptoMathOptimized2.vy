# @version ^0.3.7
# (c) Curve.Fi, 2023
# Math for 3-coin Curve cryptoswap pools
#
# Unless otherwise agreed on, only contracts owned by Curve DAO or
# Swiss Stake GmbH are allowed to call this contract.

"""
@title CurveTricryptoMathOptimized
@license MIT
@author Curve.Fi
@notice Curve AMM Math for 3 unpegged assets (e.g. ETH, BTC, USD).
"""

N_COINS: constant(uint256) = 2
A_MULTIPLIER: constant(uint256) = 10000

MIN_GAMMA: constant(uint256) = 10**10
MAX_GAMMA: constant(uint256) = 5 * 10**16

MIN_A: constant(uint256) = N_COINS**N_COINS * A_MULTIPLIER / 100
MAX_A: constant(uint256) = N_COINS**N_COINS * A_MULTIPLIER * 1000

version: public(constant(String[8])) = "v2.0.0"

event IntLog:
    my_int: uint256

# ------------------------ AMM math functions --------------------------------


@external
@view
def get_y(
    _ANN: uint256, _gamma: uint256, x: uint256[2], _D: uint256, i: uint256
) -> uint256:
    """
    @notice Calculate x[i] given other balances x[0..N_COINS-1] and invariant D.
    @dev ANN = A * N**N . AMM contract's A is actuall ANN.
    @param _ANN AMM.A() value.
    @param _gamma AMM.gamma() value.
    @param x Balances multiplied by prices and precisions of all coins.
    @param _D Invariant.
    @param i Index of coin to calculate y.
    @return y Calculated y.
    """
    return self._newton_y(_ANN, _gamma, x, _D, i)

@internal
@view
def _get_y(
    _ANN: uint256, _gamma: uint256, x: uint256[N_COINS], _D: uint256, i: uint256
) -> uint256[2]:
    # Safety checks
    assert _ANN > MIN_A - 1 and _ANN < MAX_A + 1, "dev: unsafe values A"
    assert _gamma > MIN_GAMMA - 1 and _gamma < MAX_GAMMA + 1, "dev: unsafe values gamma"
    assert _D > 10**17 - 1 and _D < 10**15 * 10**18 + 1, "dev: unsafe values D"

    for k in range(3):
        if k != i:
            frac: uint256 = x[k] * 10**18 / _D
            assert frac > 10**16 - 1 and frac < 10**20 + 1, "dev: unsafe values x[i]"

    j: uint256 = 0
    k: uint256 = 0
    if i == 0:
        j = 1
        k = 2
    elif i == 1:
        j = 0
        k = 2
    elif i == 2:
        j = 0
        k = 1

    ANN: int256 = convert(_ANN, int256)
    gamma: int256 = convert(_gamma, int256)
    D: int256 = convert(_D, int256)
    x_j: int256 = convert(x[j], int256)
    x_k: int256 = convert(x[k], int256)

    a: int256 = 10**36 / 27

    # 10**36/9 + 2*10**18*gamma/27 - D**2/x_j*gamma**2*ANN/27**2/convert(A_MULTIPLIER, int256)/x_k
    b: int256 = unsafe_sub(
        unsafe_add(
            10**36 / 9,
            unsafe_div(unsafe_mul(2 * 10**18, gamma), 27)
        ),
        unsafe_div(
            unsafe_div(
                unsafe_div(
                    unsafe_mul(unsafe_mul(unsafe_div(D**2, x_j), gamma**2), ANN),
                    27**2
                ),
                convert(A_MULTIPLIER, int256)
            ),
            x_k,
        ),
    )

    # 10**36/9 + gamma*(gamma + 4*10**18)/27 + gamma**2*(x_j+x_k-D)/D*ANN/27/convert(A_MULTIPLIER, int256)
    c: int256 = unsafe_add(
        unsafe_add(
            10**36 / 9,
            unsafe_div(unsafe_mul(gamma, unsafe_add(gamma, 4 * 10**18)), 27)
        ),
        unsafe_div(
            unsafe_div(
                unsafe_mul(
                    unsafe_div(gamma**2 * (unsafe_sub(unsafe_add(x_j, x_k), D)), D),
                    ANN
                ),
                27
            ),
            convert(A_MULTIPLIER, int256),
        ),
    )

    # (10**18 + gamma)**2/27
    d: int256 = unsafe_div(unsafe_add(10**18, gamma)**2, 27)

    # abs(3*a*c/b - b)
    d0: int256 = abs(unsafe_sub(unsafe_div(unsafe_mul(unsafe_mul(3, a), c), b), b))

    divider: int256 = 0
    if d0 > 10**48:
        divider = 10**30
    elif d0 > 10**44:
        divider = 10**26
    elif d0 > 10**40:
        divider = 10**22
    elif d0 > 10**36:
        divider = 10**18
    elif d0 > 10**32:
        divider = 10**14
    elif d0 > 10**28:
        divider = 10**10
    elif d0 > 10**24:
        divider = 10**6
    elif d0 > 10**20:
        divider = 10**2
    else:
        divider = 1

    additional_prec: int256 = 0
    if abs(a) > abs(b):
        additional_prec = abs(a) / abs(b)
        # a * additional_prec / divider
        a = unsafe_div(unsafe_mul(a, additional_prec), divider)
        b = unsafe_div(unsafe_mul(b, additional_prec), divider)
        c = unsafe_div(unsafe_mul(c, additional_prec), divider)
        d = unsafe_div(unsafe_mul(d, additional_prec), divider)
    else:
        additional_prec = abs(b) / abs(a)
        # a * additional_prec / divider
        a = unsafe_div(unsafe_div(a, additional_prec), divider)
        b = unsafe_div(unsafe_div(b, additional_prec), divider)
        c = unsafe_div(unsafe_div(c, additional_prec), divider)
        d = unsafe_div(unsafe_div(d, additional_prec), divider)

    # 3*a*c/b - b
    delta0: int256 = unsafe_sub(unsafe_div(unsafe_mul(unsafe_mul(3, a), c), b), b)

    # 9*a*c/b - 2*b - 27*a**2/b*d/b
    delta1: int256 = unsafe_sub(
        unsafe_sub(unsafe_div(unsafe_mul(unsafe_mul(9, a), c), b), unsafe_mul(2, b)),
        unsafe_div(unsafe_mul(unsafe_div(unsafe_mul(27, a**2), b), d), b),
    )

    # delta1**2 + 4*delta0**2/b*delta0
    sqrt_arg: int256 = unsafe_add(
        delta1**2,
        unsafe_mul(unsafe_div(unsafe_mul(4, delta0**2), b), delta0),
    )
    sqrt_val: int256 = 0
    if sqrt_arg > 0:
        sqrt_val = convert(isqrt(convert(sqrt_arg, uint256)), int256)
    else:
        return [self._newton_y(_ANN, _gamma, x, _D, i), 0]

    b_cbrt: int256 = 0
    if b >= 0:
        b_cbrt = convert(self._cbrt(convert(b, uint256)), int256)
    else:
        b_cbrt = -convert(self._cbrt(convert(-b, uint256)), int256)

    second_cbrt: int256 = 0
    if delta1 > 0:
        # convert(self.cbrt(convert((delta1 + sqrt_val), uint256)/2), int256)
        second_cbrt = convert(
            self._cbrt(unsafe_div(convert((unsafe_add(delta1, sqrt_val)), uint256), 2)),
            int256,
        )
    else:
        # -convert(self.cbrt(convert(-(delta1 - sqrt_val), uint256)/2), int256)
        second_cbrt = -convert(
            self._cbrt(unsafe_div(convert(-unsafe_sub(delta1, sqrt_val), uint256), 2)),
            int256,
        )

    # b_cbrt*b_cbrt/10**18*second_cbrt/10**18
    C1: int256 = unsafe_div(unsafe_mul(unsafe_div(b_cbrt**2, 10**18), second_cbrt), 10**18)

    # (b + b*delta0/C1 - C1)/3
    root_K0: int256 = unsafe_div(
        unsafe_sub(unsafe_add(b, unsafe_div(unsafe_mul(b, delta0), C1)), C1),
        3
    )

    # convert(D*D/27/x_k*D/x_j*root_K0/a, uint256)
    root: uint256 = convert(
        unsafe_div(
            unsafe_mul(
                unsafe_div(unsafe_mul(unsafe_div(unsafe_div(D**2, 27), x_k), D), x_j),
                root_K0
            ),
            a,
        ),
        uint256,
    )

    # convert(10**18*root_K0/a, uint256) ---------------------------------
    return [  #                                                           |
        root,  #                                                          |
        convert(unsafe_div(unsafe_mul(10**18, root_K0), a), uint256)  # <-
    ]


@external
@view
def newton_y(
    ANN: uint256, gamma: uint256, x: uint256[N_COINS], D: uint256, i: uint256
) -> uint256:
    return self._newton_y(
        ANN, gamma, x, D, i
    )



@internal
@view
def _newton_y(ANN: uint256, gamma: uint256, x: uint256[N_COINS], D: uint256, i: uint256) -> uint256:
    """
    Calculating x[i] given other balances x[0..N_COINS-1] and invariant D
    ANN = A * N**N
    """
    # Safety checks
    assert ANN > MIN_A - 1 and ANN < MAX_A + 1  # dev: unsafe values A
    assert gamma > MIN_GAMMA - 1 and gamma < MAX_GAMMA + 1  # dev: unsafe values gamma
    assert D > 10**17 - 1 and D < 10**15 * 10**18 + 1 # dev: unsafe values D

    x_j: uint256 = x[1 - i]
    y: uint256 = D**2 / (x_j * N_COINS**2)
    K0_i: uint256 = (10**18 * N_COINS) * x_j / D
    # S_i = x_j

    # frac = x_j * 1e18 / D => frac = K0_i / N_COINS
    assert (K0_i > 10**16*N_COINS - 1) and (K0_i < 10**20*N_COINS + 1)  # dev: unsafe values x[i]

    # x_sorted: uint256[N_COINS] = x
    # x_sorted[i] = 0
    # x_sorted = self.sort(x_sorted)  # From high to low
    # x[not i] instead of x_sorted since x_soted has only 1 element

    convergence_limit: uint256 = max(max(x_j / 10**14, D / 10**14), 100)

    for j in range(255):
        y_prev: uint256 = y

        K0: uint256 = K0_i * y * N_COINS / D
        S: uint256 = x_j + y

        _g1k0: uint256 = gamma + 10**18
        if _g1k0 > K0:
            _g1k0 = _g1k0 - K0 + 1
        else:
            _g1k0 = K0 - _g1k0 + 1

        # D / (A * N**N) * _g1k0**2 / gamma**2
        mul1: uint256 = 10**18 * D / gamma * _g1k0 / gamma * _g1k0 * A_MULTIPLIER / ANN

        # 2*K0 / _g1k0
        mul2: uint256 = 10**18 + (2 * 10**18) * K0 / _g1k0

        yfprime: uint256 = 10**18 * y + S * mul2 + mul1
        _dyfprime: uint256 = D * mul2
        if yfprime < _dyfprime:
            y = y_prev / 2
            continue
        else:
            yfprime -= _dyfprime
        fprime: uint256 = yfprime / y

        # y -= f / f_prime;  y = (y * fprime - f) / fprime
        # y = (yfprime + 10**18 * D - 10**18 * S) // fprime + mul1 // fprime * (10**18 - K0) // K0
        y_minus: uint256 = mul1 / fprime
        y_plus: uint256 = (yfprime + 10**18 * D) / fprime + y_minus * 10**18 / K0
        y_minus += 10**18 * S / fprime

        if y_plus < y_minus:
            y = y_prev / 2
        else:
            y = y_plus - y_minus

        diff: uint256 = 0
        if y > y_prev:
            diff = y - y_prev
        else:
            diff = y_prev - y
        if diff < max(convergence_limit, y / 10**14):
            frac: uint256 = y * 10**18 / D
            assert (frac > 10**16 - 1) and (frac < 10**20 + 1)  # dev: unsafe value for y
            return y

    raise "Did not converge"

@internal
@view
def _newton_y_old(
    ANN: uint256, gamma: uint256, x: uint256[N_COINS], D: uint256, i: uint256
) -> uint256:

    # Calculate x[i] given A, gamma, xp and D using newton's method.
    # This is the original method; get_y replaces it, but defaults to
    # this version conditionally.

    # Safety checks
    assert ANN > MIN_A - 1 and ANN < MAX_A + 1, "dev: unsafe values A"
    assert gamma > MIN_GAMMA - 1 and gamma < MAX_GAMMA + 1, "dev: unsafe values gamma"
    assert D > 10**17 - 1 and D < 10**15 * 10**18 + 1, "dev: unsafe values D"

    for k in range(3):
        if k != i:
            frac: uint256 = x[k] * 10**18 / D
            assert frac > 10**16 - 1 and frac < 10**20 + 1, "dev: unsafe values x[i]"

    y: uint256 = D / N_COINS
    K0_i: uint256 = 10**18
    S_i: uint256 = 0

    x_sorted: uint256[N_COINS] = x
    x_sorted[i] = 0
    x_sorted = self._sort(x_sorted)  # From high to low

    convergence_limit: uint256 = max(max(x_sorted[0] / 10**14, D / 10**14), 100)
    for j in range(2, N_COINS + 1):
        _x: uint256 = x_sorted[N_COINS - j]
        y = y * D / (_x * N_COINS)  # Small _x first
        S_i += _x
    for j in range(N_COINS - 1):
        K0_i = K0_i * x_sorted[j] * N_COINS / D  # Large _x first

    # initialise variables:
    diff: uint256 = 0
    y_prev: uint256 = 0
    K0: uint256 = 0
    S: uint256 = 0
    _g1k0: uint256 = 0
    mul1: uint256 = 0
    mul2: uint256 = 0
    yfprime: uint256 = 0
    _dyfprime: uint256 = 0
    fprime: uint256 = 0
    y_minus: uint256 = 0
    y_plus: uint256 = 0

    for j in range(255):

        y_prev = y

        K0 = K0_i * y * N_COINS / D
        S = S_i + y

        _g1k0 = gamma + 10**18
        if _g1k0 > K0:
            _g1k0 = _g1k0 - K0 + 1
        else:
            _g1k0 = K0 - _g1k0 + 1

        mul1 = 10**18 * D / gamma * _g1k0 / gamma * _g1k0 * A_MULTIPLIER / ANN

        # 2*K0 / _g1k0
        mul2 = 10**18 + (2 * 10**18) * K0 / _g1k0

        yfprime = 10**18 * y + S * mul2 + mul1
        _dyfprime = D * mul2
        if yfprime < _dyfprime:
            y = y_prev / 2
            continue
        else:
            yfprime -= _dyfprime

        fprime = yfprime / y

        # y -= f / f_prime;  y = (y * fprime - f) / fprime
        # y = (yfprime + 10**18 * D - 10**18 * S) // fprime + mul1 // fprime * (10**18 - K0) // K0
        y_minus = mul1 / fprime
        y_plus = (
            yfprime + 10**18 * D
        ) / fprime + y_minus * 10**18 / K0
        y_minus += 10**18 * S / fprime

        if y_plus < y_minus:
            y = y_prev / 2
        else:
            y = y_plus - y_minus

        if y > y_prev:
            diff = y - y_prev
        else:
            diff = y_prev - y

        if diff < max(convergence_limit, y / 10**14):
            frac: uint256 = y * 10**18 / D
            assert (frac > 10**16 - 1) and (frac < 10**20 + 1), "dev: unsafe value for y"
            return y

    raise "Did not converge"


@external
@view
def newton_D(ANN: uint256, gamma: uint256, x_unsorted: uint256[N_COINS]) -> uint256:
    # Safety checks
    assert ANN > MIN_A - 1 and ANN < MAX_A + 1  # dev: unsafe values A
    assert gamma > MIN_GAMMA - 1 and gamma < MAX_GAMMA + 1  # dev: unsafe values gamma

    # Initial value of invariant D is that for constant-product invariant
    x: uint256[N_COINS] = x_unsorted
    if x[0] < x[1]:
        x = [x_unsorted[1], x_unsorted[0]]

    assert x[0] > 10**9 - 1 and x[0] < 10**15 * 10**18 + 1  # dev: unsafe values x[0]
    assert x[1] * 10**18 / x[0] > 10**14-1  # dev: unsafe values x[i] (input)


    D: uint256 = N_COINS * self._geometric_mean(x)
    S: uint256 = x[0] + x[1]

    for i in range(255):
        D_prev: uint256 = D

        # K0: uint256 = 10**18
        # for _x in x:
        #     K0 = K0 * _x * N_COINS / D
        # collapsed for 2 coins
        K0: uint256 = (10**18 * N_COINS**2) * x[0] / D * x[1] / D

        _g1k0: uint256 = gamma + 10**18
        if _g1k0 > K0:
            _g1k0 = _g1k0 - K0 + 1
        else:
            _g1k0 = K0 - _g1k0 + 1

        # D / (A * N**N) * _g1k0**2 / gamma**2
        mul1: uint256 = 10**18 * D / gamma * _g1k0 / gamma * _g1k0 * A_MULTIPLIER / ANN

        # 2*N*K0 / _g1k0
        mul2: uint256 = (2 * 10**18) * N_COINS * K0 / _g1k0

        neg_fprime: uint256 = (S + S * mul2 / 10**18) + mul1 * N_COINS / K0 - mul2 * D / 10**18

        # D -= f / fprime
        D_plus: uint256 = D * (neg_fprime + S) / neg_fprime
        D_minus: uint256 = D*D / neg_fprime
        if 10**18 > K0:
            D_minus += D * (mul1 / neg_fprime) / 10**18 * (10**18 - K0) / K0
        else:
            D_minus -= D * (mul1 / neg_fprime) / 10**18 * (K0 - 10**18) / K0

        if D_plus > D_minus:
            D = D_plus - D_minus
        else:
            D = (D_minus - D_plus) / 2

        diff: uint256 = 0
        if D > D_prev:
            diff = D - D_prev
        else:
            diff = D_prev - D
        if diff * 10**14 < max(10**16, D):  # Could reduce precision for gas efficiency here
            # Test that we are safe with the next newton_y
            for _x in x:
                frac: uint256 = _x * 10**18 / D
                assert (frac > 10**16 - 1) and (frac < 10**20 + 1)  # dev: unsafe values x[i]
            return D

    raise "Did not converge"



@internal
@view
def _get_dxdy(
    x1: int256,
    x2: int256,
    x3: int256,
    a: int256,
    b: int256,
    c: int256,
) -> uint256:

    # p = 10**18*x2*( 10**18*a - b*(x2 + x3)/10**18 - c*(2*x1 + x2 + x3)/10**18) / x1*(-10**18*a + b*(x1 + x3)/10**18 + c*(x1 + 2*x2 + x3)/10**18)
    p: int256 = unsafe_div(
        unsafe_mul(
            unsafe_mul(10**18, x2),
            unsafe_sub(
                unsafe_sub(unsafe_mul(10**18, a), unsafe_div(unsafe_mul(b, unsafe_add(x2, x3)), 10**18)),
                unsafe_div(unsafe_mul(c, unsafe_add(unsafe_add(unsafe_mul(2, x1), x2), x3)), 10**18)
            )
        ),
        unsafe_mul(
            x1,
            unsafe_add(
                unsafe_add(unsafe_mul(-10**18, a), unsafe_div(unsafe_mul(b, unsafe_add(x1, x3)), 10**18)),
                unsafe_div(unsafe_mul(c, unsafe_add(unsafe_add(x1, unsafe_mul(2, x2)), x3)), 10**18)
            )
        )
    )

    return convert(-p, uint256)


# --------------------------- Math Utils -------------------------------------


@external
@view
def cbrt(x: uint256) -> uint256:
    """
    @notice Calculate the cubic root of a number in 1e18 precision
    @dev Consumes around 1500 gas units
    @param x The number to calculate the cubic root of
    @return The cubic root of the number
    """
    return self._cbrt(x)


@external
@view
def geometric_mean(_x: uint256[2]) -> uint256:
    """
    @notice Calculate the geometric mean of a list of numbers in 1e18 precision.
    @param _x list of 3 numbers to sort
    @return  The geometric mean of the list of numbers
    """
    return self._geometric_mean(_x)


@external
@view
def reduction_coefficient(x: uint256[N_COINS], fee_gamma: uint256) -> uint256:
    """
    @notice Calculates the reduction coefficient for the given x and fee_gamma
    @dev This method is used for calculating fees.
    @param x The x values
    @param fee_gamma The fee gamma value
    """
    return self._reduction_coefficient(x, fee_gamma)


@external
@view
def wad_exp(_power: int256) -> uint256:
    """
    @notice Calculates the e**x with 1e18 precision
    @param _power The number to calculate the exponential of
    @return The exponential of the given number
    """
    return self._exp(_power)


@internal
@pure
def _reduction_coefficient(x: uint256[N_COINS], fee_gamma: uint256) -> uint256:

    # fee_gamma / (fee_gamma + (1 - K))
    # where
    # K = prod(x) / (sum(x) / N)**N
    # (all normalized to 1e18)

    K: uint256 = 10**18
    S: uint256 = x[0]
    S = unsafe_add(S, x[1])
    #S = unsafe_add(S, x[2])

    # Could be good to pre-sort x, but it is used only for dynamic fee,
    # so that is not so important
    K = unsafe_div(unsafe_mul(unsafe_mul(K, N_COINS), x[0]), S)
    K = unsafe_div(unsafe_mul(unsafe_mul(K, N_COINS), x[1]), S)
    #K = unsafe_div(unsafe_mul(unsafe_mul(K, N_COINS), x[2]), S)

    if fee_gamma > 0:
        K = unsafe_mul(fee_gamma, 10**18) / unsafe_sub(unsafe_add(fee_gamma, 10**18), K)

    return K


@internal
@pure
def _exp(_power: int256) -> uint256:

    # This implementation is borrowed from transmissions11 and Remco Bloemen:
    # https://github.com/transmissions11/solmate/blob/main/src/utils/SignedWadMath.sol
    # Method: wadExp

    if _power <= -42139678854452767551:
        return 0

    if _power >= 135305999368893231589:
        raise "exp overflow"

    x: int256 = unsafe_div(unsafe_mul(_power, 2**96), 10**18)

    k: int256 = unsafe_div(
        unsafe_add(
            unsafe_div(unsafe_mul(x, 2**96), 54916777467707473351141471128),
            2**95,
        ),
        2**96,
    )
    x = unsafe_sub(x, unsafe_mul(k, 54916777467707473351141471128))

    y: int256 = unsafe_add(x, 1346386616545796478920950773328)
    y = unsafe_add(
        unsafe_div(unsafe_mul(y, x), 2**96), 57155421227552351082224309758442
    )
    p: int256 = unsafe_sub(unsafe_add(y, x), 94201549194550492254356042504812)
    p = unsafe_add(unsafe_div(unsafe_mul(p, y), 2**96), 28719021644029726153956944680412240)
    p = unsafe_add(unsafe_mul(p, x), (4385272521454847904659076985693276 * 2**96))

    q: int256 = x - 2855989394907223263936484059900
    q = unsafe_add(unsafe_div(unsafe_mul(q, x), 2**96), 50020603652535783019961831881945)
    q = unsafe_sub(unsafe_div(unsafe_mul(q, x), 2**96), 533845033583426703283633433725380)
    q = unsafe_add(unsafe_div(unsafe_mul(q, x), 2**96), 3604857256930695427073651918091429)
    q = unsafe_sub(unsafe_div(unsafe_mul(q, x), 2**96), 14423608567350463180887372962807573)
    q = unsafe_add(unsafe_div(unsafe_mul(q, x), 2**96), 26449188498355588339934803723976023)

    return shift(
        unsafe_mul(
            convert(unsafe_div(p, q), uint256),
            3822833074963236453042738258902158003155416615667
        ),
        unsafe_sub(k, 195),
    )


@internal
@pure
def _log2(x: uint256) -> int256:

    # Compute the binary logarithm of `x`

    # This was inspired from Stanford's 'Bit Twiddling Hacks' by Sean Eron Anderson:
    # https://graphics.stanford.edu/~seander/bithacks.html#IntegerLog
    #
    # More inspiration was derived from:
    # https://github.com/transmissions11/solmate/blob/main/src/utils/SignedWadMath.sol

    log2x: int256 = 0
    if x > 340282366920938463463374607431768211455:
        log2x = 128
    if unsafe_div(x, shift(2, log2x)) > 18446744073709551615:
        log2x = log2x | 64
    if unsafe_div(x, shift(2, log2x)) > 4294967295:
        log2x = log2x | 32
    if unsafe_div(x, shift(2, log2x)) > 65535:
        log2x = log2x | 16
    if unsafe_div(x, shift(2, log2x)) > 255:
        log2x = log2x | 8
    if unsafe_div(x, shift(2, log2x)) > 15:
        log2x = log2x | 4
    if unsafe_div(x, shift(2, log2x)) > 3:
        log2x = log2x | 2
    if unsafe_div(x, shift(2, log2x)) > 1:
        log2x = log2x | 1

    return log2x


@internal
@pure
def _cbrt(x: uint256) -> uint256:

    xx: uint256 = 0
    if x >= 115792089237316195423570985008687907853269 * 10**18:
        xx = x
    elif x >= 115792089237316195423570985008687907853269:
        xx = unsafe_mul(x, 10**18)
    else:
        xx = unsafe_mul(x, 10**36)

    log2x: int256 = self._log2(xx)

    # When we divide log2x by 3, the remainder is (log2x % 3).
    # So if we just multiply 2**(log2x/3) and discard the remainder to calculate our
    # guess, the newton method will need more iterations to converge to a solution,
    # since it is missing that precision. It's a few more calculations now to do less
    # calculations later:
    # pow = log2(x) // 3
    # remainder = log2(x) % 3
    # initial_guess = 2 ** pow * cbrt(2) ** remainder
    # substituting -> 2 = 1.26 ≈ 1260 / 1000, we get:
    #
    # initial_guess = 2 ** pow * 1260 ** remainder // 1000 ** remainder

    remainder: uint256 = convert(log2x, uint256) % 3
    a: uint256 = unsafe_div(
        unsafe_mul(
            pow_mod256(2, unsafe_div(convert(log2x, uint256), 3)),  # <- pow
            pow_mod256(1260, remainder),
        ),
        pow_mod256(1000, remainder),
    )

    # Because we chose good initial values for cube roots, 7 newton raphson iterations
    # are just about sufficient. 6 iterations would result in non-convergences, and 8
    # would be one too many iterations. Without initial values, the iteration count
    # can go up to 20 or greater. The iterations are unrolled. This reduces gas costs
    # but takes up more bytecode:
    a = unsafe_div(unsafe_add(unsafe_mul(2, a), unsafe_div(xx, unsafe_mul(a, a))), 3)
    a = unsafe_div(unsafe_add(unsafe_mul(2, a), unsafe_div(xx, unsafe_mul(a, a))), 3)
    a = unsafe_div(unsafe_add(unsafe_mul(2, a), unsafe_div(xx, unsafe_mul(a, a))), 3)
    a = unsafe_div(unsafe_add(unsafe_mul(2, a), unsafe_div(xx, unsafe_mul(a, a))), 3)
    a = unsafe_div(unsafe_add(unsafe_mul(2, a), unsafe_div(xx, unsafe_mul(a, a))), 3)
    a = unsafe_div(unsafe_add(unsafe_mul(2, a), unsafe_div(xx, unsafe_mul(a, a))), 3)
    a = unsafe_div(unsafe_add(unsafe_mul(2, a), unsafe_div(xx, unsafe_mul(a, a))), 3)

    if x >= 115792089237316195423570985008687907853269 * 10**18:
        return a * 10**12
    elif x >= 115792089237316195423570985008687907853269:
        return a * 10**6

    return a


@internal
@pure
def _sort(unsorted_x: uint256[N_COINS]) -> uint256[N_COINS]:

    # Sorts a three-array number in a descending order:

    x: uint256[N_COINS] = unsorted_x
    temp_var: uint256 = x[0]
    if x[0] < x[1]:
        x = [unsorted_x[1], unsorted_x[0]]
    else:
        x = unsorted_x
    return x


@internal
@view
def _geometric_mean(unsorted_x: uint256[2]) -> uint256:

    # calculates a geometric mean for two numbers.

    """
    (x[0] * x[1] * ...) ** (1/N)
    """
    x: uint256[N_COINS] = unsorted_x
    if True and x[0] < x[1]:
        x = [unsorted_x[1], unsorted_x[0]]
    D: uint256 = x[0]
    diff: uint256 = 0
    for i in range(255):
        D_prev: uint256 = D
        # tmp: uint256 = 10**18
        # for _x in x:
        #     tmp = tmp * _x / D
        # D = D * ((N_COINS - 1) * 10**18 + tmp) / (N_COINS * 10**18)
        # line below makes it for 2 coins
        D = (D + x[0] * x[1] / D) / N_COINS
        if D > D_prev:
            diff = D - D_prev
        else:
            diff = D_prev - D
        if diff <= 1 or diff * 10**18 < D:
            return D
    raise "Did not converge"

