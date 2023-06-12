# @version ^0.3.7
# (c) Curve.Fi, 2023

"""
@title Universal Views Controller
@license MIT
@author Curve.Fi
@notice This contract contains view-only external methods
@dev May be gas-inefficient when called from other smart contracts.
"""

from vyper.interfaces import ERC20

# XXX INTERFACES NEED CLEANUP

interface MetaRegistry:
    def get_registry(i: uint256) -> address: view
    def get_registry_handlers_from_pool(addr: address) -> address[10]: view
    def get_decimals(_addr: address) -> uint256[8]: view
    def get_lp_token(_addr: address) -> address: view
    def get_n_coins(_addr: address) -> uint256: view
    def get_coins(_addr: address) -> address[8]: view

interface Factory:
    def is_registered(addr: address) -> bool: view

interface CurveCalculator:
    def get_dx(
         n_coins: int128, 
         balances: uint256[8],
         amp: uint256,
         fee: uint256,
         rates: uint256[8],
         precisions: uint256[8],
         underlying: bool,
         i: int128,
         j: int128,
         dy: uint256
    ) -> uint256: view

interface Math:
    def newton_D(
        ANN: uint256,
        gamma: uint256,
        x_unsorted: uint256[N_COINS],
        K0_prev: uint256
    ) -> uint256: view
    def get_y(
        ANN: uint256,
        gamma: uint256,
        x: uint256[N_COINS],
        D: uint256,
        i: uint256,
    ) -> uint256[2]: view
    def reduction_coefficient(x: uint256[N_COINS], fee_gamma: uint256) -> uint256: view

interface Curve_3pool:
    def A() -> uint256: view
    def gamma() -> uint256: view
    def price_scale(i: uint256) -> uint256: view
    def price_oracle(i: uint256) -> uint256: view
    def get_virtual_price() -> uint256: view
    def balances(i: uint256) -> uint256: view
    def D() -> uint256: view
    def fee_calc(xp: uint256[N_COINS]) -> uint256: view
    def calc_token_amount(amounts: uint256[3], deposit: bool) -> uint256: view
    def calc_token_fee(
        amounts: uint256[N_COINS], xp: uint256[N_COINS]
    ) -> uint256: view
    def packed_fee_params() -> uint256: view
    def future_A_gamma_time() -> uint256: view
    def totalSupply() -> uint256: view
    def precisions() -> uint256[N_COINS]: view


interface Curve_2pool:
    def A() -> uint256: view
    def gamma() -> uint256: view
    def price_scale() -> uint256: view
    def price_oracle() -> uint256: view
    def get_dy(i: uint256, j: uint256, dx: uint256) -> uint256: view
    def get_virtual_price() -> uint256: view
    def balances(i: uint256) -> uint256: view
    def calc_token_amount(amounts: uint256[2], deposit: bool) -> uint256: view
    def D() -> uint256: view
    def fee() -> uint256: view
    def fee_calc(xp: uint256[2]) -> uint256: view
    def calc_token_fee(
        amounts: uint256[2], xp: uint256[2]
    ) -> uint256: view
    def future_A_gamma_time() -> uint256: view
    def totalSupply() -> uint256: view
    def precisions() -> uint256[2]: view
    def fee_gamma() -> uint256: view
    def mid_fee() -> uint256: view
    def out_fee() -> uint256: view

interface Curve_2pool_calc_token_opt:
    def calc_token_amount(amounts: uint256[2]) -> uint256: view

interface Curve_2pool_int128:
    def get_dy(i: int128, j: int128, dx: uint256) -> uint256: view

interface Curve_3pool_int128:
    def fee() -> uint256: view
    def get_dy(i: int128, j: int128, dx: uint256) ->  uint256: view

N_COINS: constant(uint256) = 3
PRECISION: constant(uint256) = 10**18

math: Math
meta: MetaRegistry
calc: CurveCalculator


#######################
# EXTERNAL
#######################


@external
def __init__(_math3: address):
    self.math = Math(_math3)
    self.meta = MetaRegistry(0xF98B45FA17DE75FB1aD0e7aFD971b0ca00e379fC)
    self.calc = CurveCalculator(0xc1DB00a8E5Ef7bfa476395cdbcc98235477cDE4E)


@external
@view
def coins(swap: address, index: uint256) -> address:
    """
    @notice Get the coins within a pool
    @dev For metapools, these are the wrapped coin addresses
    @param swap Pool address
    @param index id of registry handler
    @return Coin address for index
    """
    return self.meta.get_coins(swap)[index]


@external
@view
def get_dy(i: uint256, j: uint256, dx: uint256, swap: address) -> uint256:
    """
    @notice Calculate the current output dy given input dx
    @dev Index values can be found via the `coins` public getter method
    @param i Index value for the coin to send
    @param j Index value of the coin to receive
    @param dx Amount of `i` being exchanged
    @return Amount of `j` predicted
    """
    dy: uint256 = 0
    n_coins: uint256 = self.meta.get_n_coins(swap) 

    if n_coins == 3:
        xp: uint256[N_COINS] = empty(uint256[N_COINS])
        dy, xp = self._get_dy_nofee_3(i, j, dx, swap)
        dy -= Curve_3pool(swap).fee_calc(xp) * dy / 10 ** 10
    elif n_coins == 2:
        dy = self._safe_get_dy_2(i, j, dx, swap)
    else:
        assert False, "XXX n_coins must be 2 or 3"
    
    return dy


@view
@external
def get_dx(i: uint256, j: uint256, dy: uint256, swap: address) -> uint256:
    """
    @notice Calculate the current input dx given output dy
    @dev Index values can be found via the `coins` public getter method
    @param i Index value for the coin to send
    @param j Index value of the coin to receive
    @param dy Amount of `j` being received after exchange
    @return Amount of `i` predicted
    """
    dx: uint256 = 0
    fee_dy: uint256 = 0
    _dy: uint256 = dy
    n_coins: uint256 = self.meta.get_n_coins(swap) 
    is_v2: bool = self.is_v2(swap)

    if n_coins == 3:
        xp: uint256[3] = empty(uint256[3])
        dx, xp = self._get_dx_fee_3(i, j, _dy, swap)
        for k in range(5):
            dx, xp = self._get_dx_fee_3(i, j, _dy, swap)
            fee_dy = Curve_3pool(swap).fee_calc(xp) * _dy / 10 ** 10
            _dy = dy + fee_dy + 1
    elif is_v2:
        assert False, "XXX Not Implemented"
    else:
        precisions: uint256[8] = self._get_precisions_from_metaregistry(swap)  
        A_param: uint256 = Curve_2pool(swap).A()
        fees: uint256 = Curve_2pool(swap).fee()

        balances: uint256[8] = empty(uint256[8])
        rates: uint256[8] = empty(uint256[8]) # XXX Update for rated pools
        for _i in range(8):
            if precisions[_i] > 0:
                balances[_i] = Curve_2pool(swap).balances(_i)
                rates[_i] = 10 ** 18 / precisions[_i]
         
        dx = self.calc.get_dx(2, balances, A_param, fees, rates, precisions, False, convert(i, int128), convert(j, int128), dy) 

    return dx


@view
@external
def calc_token_amount(
    amounts: DynArray[uint256, N_COINS], deposit: bool, swap: address
) -> uint256:
    """
    @notice Calculate addition or reduction in token supply from a deposit or withdrawal
    @param amounts Amount of each coin being deposited
    @param deposit set True for deposits, False for withdrawals
    @return Expected amount of LP tokens received
    """

    n_coins: uint256 = len(amounts)
    d_token: uint256 = 0

    if self._get_registry(swap) in [0x9335BF643C455478F8BE40fA20B5164b90215B80]:
        amountsp: uint256[N_COINS] = empty(uint256[N_COINS])
        xp: uint256[N_COINS] = empty(uint256[N_COINS])
        
        amt_arr: uint256[3] = [amounts[0], amounts[1], amounts[2]]
        d_token, amountsp, xp = self._calc_dtoken_nofee(amt_arr, deposit, swap)
        d_token -= (
            Curve_3pool(swap).calc_token_fee(amountsp, xp) * d_token / 10**10 + 1
        )
    elif n_coins == 3:
        amt_arr: uint256[3] = [amounts[0], amounts[1], amounts[2]]
        d_token = Curve_3pool(swap).calc_token_amount(amt_arr, True)
    elif n_coins == 2:
        amt_arr: uint256[2] = [amounts[0], amounts[1]]
        if self._get_registry(swap) in [0x5f493fEE8D67D3AE3bA730827B34126CFcA0ae94]: 
            d_token = Curve_2pool_calc_token_opt(swap).calc_token_amount(amt_arr)
        else:
            d_token = Curve_2pool(swap).calc_token_amount(amt_arr, True)
    else:
        assert False, "XXX Pool not supported"

    return d_token


@external
@view
def calc_fee_get_dy(i: uint256, j: uint256, dx: uint256, swap: address) -> uint256:
    """
    @notice Returns the fee charged by the pool at current state.
    @param i Index value for the coin to send
    @param j Index value of the coin to receive
    @param dx Amount of `i` being traded 
    @param swap Address of pool
    @return uint256 Fee value.
    """

    is_v2: bool = self.is_v2(swap)
    n_coins: uint256 = self.meta.get_n_coins(swap) 

    return_value: uint256 = 0 
    if self._get_registry(swap) in [0x9335BF643C455478F8BE40fA20B5164b90215B80]:
        dy: uint256 = 0
        xp: uint256[N_COINS] = empty(uint256[N_COINS])
        dy, xp = self._get_dy_nofee_3(i, j, dx, swap)
        
        return_value = Curve_3pool(swap).fee_calc(xp) * dy / 10**10
    elif n_coins == 3 and is_v2 == True:
        xp: uint256[3] = empty(uint256[3])
        dy: uint256 = 0
        dy, xp = self._get_dy_nofee_3(i, j, dx, swap)
        return_value = Curve_3pool(swap).fee_calc(xp) 
    elif is_v2:
        return_value = self._calc_v2_fee(i, j, dx, swap)
    elif n_coins == 3:
        getdy: uint256 = self._safe_get_dy_3(i, j, dx, swap) 
        return_value = getdy * 10 ** 10 / (10 ** 10 - Curve_3pool_int128(swap).fee())
    else:
        getdy: uint256 = self._safe_get_dy_2(i, j, dx, swap)
        return_value = getdy * 10 ** 10 / (10 ** 10 - Curve_2pool(swap).fee())

    return return_value


@view
@external
def calc_fee_token_amount(
    amounts: uint256[N_COINS], deposit: bool, swap: address
) -> uint256:
    """
    @notice Returns the fee charged on the given amounts for add_liquidity.
    @param amounts The amounts of coins being added to the pool.
    @param deposit set True for deposits, False for withdrawals
    @param swap Address of pool
    @return uint256 Fee charged.
    """

    is_v2: bool = self.is_v2(swap)
    n_coins: uint256 = self.meta.get_n_coins(swap) 

    return_value: uint256 = 0 
    if self.is_tng(swap):
        # Tricrypto: NG
        d_token: uint256 = 0
        amountsp: uint256[N_COINS] = empty(uint256[N_COINS])
        xp: uint256[N_COINS] = empty(uint256[N_COINS])
        d_token, amountsp, xp = self._calc_dtoken_nofee(amounts, deposit, swap)

        return_value = Curve_3pool(swap).calc_token_fee(amountsp, xp) * d_token / 10**10 + 1
    elif n_coins == 3 and is_v2 == True:
        # Tricrypto: OS style
        assert False, "TOS"
    elif is_v2:
        # 2 coin v2
        assert False, "2 coin v2"
    elif n_coins == 3:
        # 3pool
        assert False, "3pool"
    else:
        # Pool
        assert False, "Pool"
  
    return return_value


@external
@view
def calc_fee_withdraw_one_coin(token_amount: uint256, i: uint256, swap: address) -> uint256:
    """
    @notice Returns the fee charged by the pool at current state for removing one coine.
    @param token_amount Quantity of lp tokens to withdraw
    @param i Index value for the coin to receive
    @param swap Address of pool
    @return uint256 Fee value.
    """

    n_coins: uint256 = self.meta.get_n_coins(swap) 
    is_v2: bool = self.is_v2(swap)

    return_value: uint256 = 0 
    if self._get_registry(swap) in [0x9335BF643C455478F8BE40fA20B5164b90215B80]:
        return_value = self._calc_withdraw_one_coin(swap, token_amount, i)[1]
    elif n_coins == 3 and is_v2 == True:
        assert False, "TOS"
    elif is_v2:
        assert False, "2 coin v2"
    elif n_coins == 3:
        assert False, "3pool"
    else:
        assert False, "Typical"

    return return_value


#######################
# INTERNAL
#######################


@internal
@view
def _get_registry(_addr: address) -> address:
    return self.meta.get_registry_handlers_from_pool(_addr)[0]


@internal
@view
def _use_128(_addr: address) -> bool:
    if self._get_registry(_addr) in [0x46a8a9CF4Fc8e99EC3A14558ACABC1D93A27de68, 0xFD5dB7463a3aB53fD211b4af195c5BCCC1A03890, 0x127db66E7F0b16470Bec194d0f496F9Fa065d0A9]:
        return True
    return False 

@internal
@view
def _safe_get_dy_3(i: uint256, j: uint256, dx: uint256, swap: address) -> uint256:
    # XXX Need to check/break this by int128/uint256
    return Curve_3pool_int128(swap).get_dy(convert(i, int128), convert(j, int128), dx)


@internal
@view
def _safe_get_dy_2(i: uint256, j: uint256, dx: uint256, swap: address) -> uint256:
    dy: uint256 = 0
    if self._use_128(swap):
        dy = Curve_2pool_int128(swap).get_dy(convert(i, int128), convert(j, int128), dx)
    else:
        dy = Curve_2pool(swap).get_dy(i, j, dx)
    return dy

@internal
@view
def _get_precisions_from_metaregistry(swap: address) -> uint256[8]:
    decimals: uint256[8] = self.meta.get_decimals(swap)
    ret_array: uint256[8] = empty(uint256[8])

    for i in range(8):
        if decimals[i] > 0:
            ret_array[i] = 10 ** (18 - decimals[i])

    return ret_array

@internal
@view
def _prep_calc(swap: address) -> (
    uint256[N_COINS],
    uint256,
    uint256,
    uint256[N_COINS-1],
    uint256,
    uint256,
    uint256[N_COINS]
):
    precisions_8: uint256[8] = self._get_precisions_from_metaregistry(swap)
    precisions: uint256[3] = [precisions_8[0], precisions_8[1], precisions_8[2]] 
    
    token_supply: uint256 = Curve_3pool(self.meta.get_lp_token(swap)).totalSupply()

    xp: uint256[N_COINS] = empty(uint256[N_COINS])
    for k in range(N_COINS):
        xp[k] = Curve_3pool(swap).balances(k)

    price_scale: uint256[N_COINS - 1] = empty(uint256[N_COINS - 1])
    for k in range(N_COINS - 1):
        price_scale[k] = Curve_3pool(swap).price_scale(k)

    A: uint256 = Curve_3pool(swap).A()
    gamma: uint256 = Curve_3pool(swap).gamma()
    D: uint256 = self._calc_D_ramp(
        A, gamma, xp, precisions, price_scale, swap
    )

    return xp, D, token_supply, price_scale, A, gamma, precisions


@internal
@view
def _calc_D_ramp(
    A: uint256,
    gamma: uint256,
    xp: uint256[N_COINS],
    precisions: uint256[N_COINS],
    price_scale: uint256[N_COINS - 1],
    swap: address
) -> uint256:

    D: uint256 = Curve_3pool(swap).D()
    if Curve_3pool(swap).future_A_gamma_time() > 0:
        _xp: uint256[N_COINS] = xp
        _xp[0] *= precisions[0]
        for k in range(N_COINS - 1):
            _xp[k + 1] = (
                _xp[k + 1] * price_scale[k] * precisions[k + 1] / PRECISION
            )
        D = self.math.newton_D(A, gamma, _xp, 0)

    return D


@internal
@view
def _get_dx_fee_3(
    i: uint256, j: uint256, dy: uint256, swap: address
) -> (uint256, uint256[N_COINS]):

    # here, dy must include fees (and 1 wei offset)
    assert i != j and i < N_COINS and j < N_COINS, "coin index out of range"
    assert dy > 0, "do not exchange out 0 coins"

    xp: uint256[N_COINS] = empty(uint256[N_COINS])
    precisions: uint256[N_COINS] = empty(uint256[N_COINS])
    price_scale: uint256[N_COINS-1] = empty(uint256[N_COINS-1])
    D: uint256 = 0
    token_supply: uint256 = 0
    A: uint256 = 0
    gamma: uint256 = 0

    xp, D, token_supply, price_scale, A, gamma, precisions = self._prep_calc(swap)

    # adjust xp with output dy. dy contains fee element, which we handle later
    # (hence this internal method is called _get_dx_fee)
    xp[j] -= dy
    xp[0] *= precisions[0]
    for k in range(N_COINS - 1):
        xp[k + 1] = xp[k + 1] * price_scale[k] * precisions[k + 1] / PRECISION

    x_out: uint256[2] = self.math.get_y(A, gamma, xp, D, i)
    dx: uint256 = x_out[0] - xp[i]
    xp[i] = x_out[0]
    if i > 0:
        dx = dx * PRECISION / price_scale[i - 1]
    dx /= precisions[i]

    return dx, xp


@internal
@view
def _get_dy_nofee_3(
    i: uint256, j: uint256, dx: uint256, swap: address
) -> (uint256, uint256[N_COINS]):

    assert i != j and i < N_COINS and j < N_COINS, "coin index out of range"
    assert dx > 0, "do not exchange 0 coins"

    xp: uint256[N_COINS] = empty(uint256[N_COINS])

    precisions_8: uint256[8] = self._get_precisions_from_metaregistry(swap)
    precisions: uint256[3] = [precisions_8[0], precisions_8[1], precisions_8[2]] 
 
    price_scale: uint256[N_COINS - 1] = empty(uint256[N_COINS - 1])
    for k in range(N_COINS - 1):
        price_scale[k] = Curve_3pool(swap).price_scale(k)
    for k in range(N_COINS):
        xp[k] = Curve_3pool(swap).balances(k)

    A: uint256 = Curve_3pool(swap).A()
    gamma: uint256 = Curve_3pool(swap).gamma()
    D: uint256 = self._calc_D_ramp(
        A, gamma, xp, precisions, price_scale, swap
    )

    xp[i] += dx
    xp[0] *= precisions[0]
    for k in range(N_COINS - 1):
        xp[k + 1] = xp[k + 1] * price_scale[k] * precisions[k + 1] / PRECISION

    y_out: uint256[2] = self.math.get_y(A, gamma, xp, D, j)
    dy: uint256 = xp[j] - y_out[0] - 1
    xp[j] = y_out[0]
    if j > 0:
        dy = dy * PRECISION / price_scale[j - 1]
    dy /= precisions[j]

    return dy, xp


@internal
@view
def _calc_dtoken_nofee(
    amounts: uint256[N_COINS], deposit: bool, swap: address
) -> (uint256, uint256[N_COINS], uint256[N_COINS]):

    precisions: uint256[N_COINS] = Curve_3pool(swap).precisions()
    token_supply: uint256 = Curve_3pool(swap).totalSupply()
    xp: uint256[N_COINS] = empty(uint256[N_COINS])
    for k in range(N_COINS):
        xp[k] = Curve_3pool(swap).balances(k)

    price_scale: uint256[N_COINS - 1] = empty(uint256[N_COINS - 1])
    for k in range(N_COINS - 1):
        price_scale[k] = Curve_3pool(swap).price_scale(k)

    A: uint256 = Curve_3pool(swap).A()
    gamma: uint256 = Curve_3pool(swap).gamma()
    D0: uint256 = self._calc_D_ramp(
        A, gamma, xp, precisions, price_scale, swap
    )

    amountsp: uint256[N_COINS] = amounts
    if deposit:
        for k in range(N_COINS):
            xp[k] += amounts[k]
    else:
        for k in range(N_COINS):
            xp[k] -= amounts[k]

    xp[0] *= precisions[0]
    amountsp[0] *= precisions[0]
    for k in range(N_COINS - 1):
        p: uint256 = price_scale[k] * precisions[k + 1]
        xp[k + 1] = xp[k + 1] * p / PRECISION
        amountsp[k + 1] = amountsp[k + 1] * p / PRECISION

    D: uint256 = self.math.newton_D(A, gamma, xp, 0)
    d_token: uint256 = token_supply * D / D0

    if deposit:
        d_token -= token_supply
    else:
        d_token = token_supply - d_token

    return d_token, amountsp, xp


@view
@internal
def _calc_withdraw_one_coin(swap: address, token_amount: uint256, i: uint256) -> (uint256,uint256):
    token_supply: uint256 = Curve_3pool(swap).totalSupply()
    assert token_amount <= token_supply  # dev: token amount more than supply
    assert i < N_COINS  # dev: coin out of range


    xx: uint256[N_COINS] = empty(uint256[N_COINS])
    price_scale: uint256[N_COINS-1] = empty(uint256[N_COINS-1])
    for k in range(N_COINS):
        xx[k] = Curve_3pool(swap).balances(k)
        if k > 0:
            price_scale[k - 1] = Curve_3pool(swap).price_scale(k - 1)

    precisions: uint256[N_COINS] = Curve_3pool(swap).precisions()
    A: uint256 = Curve_3pool(swap).A()
    gamma: uint256 = Curve_3pool(swap).gamma()
    xp: uint256[N_COINS] = precisions
    D0: uint256 = 0
    p: uint256 = 0

    price_scale_i: uint256 = PRECISION * precisions[0]
    xp[0] *= xx[0]
    for k in range(1, N_COINS):

        p = price_scale[k-1]
        if i == k:
            price_scale_i = p * xp[i]
        xp[k] = xp[k] * xx[k] * p / PRECISION

    if Curve_3pool(swap).future_A_gamma_time() > block.timestamp:
        D0 = self.math.newton_D(A, gamma, xp, 0)
    else:
        D0 = Curve_3pool(swap).D()

    D: uint256 = D0

    fee: uint256 = self._fee(xp, swap)
    dD: uint256 = token_amount * D / token_supply

    D_fee: uint256 = fee * dD / (2 * 10**10) + 1
    approx_fee: uint256 = N_COINS * D_fee * xx[i] / D

    D -= (dD - D_fee)

    y_out: uint256[2] = self.math.get_y(A, gamma, xp, D, i)
    dy: uint256 = (xp[i] - y_out[0]) * PRECISION / price_scale_i
    xp[i] = y_out[0]

    return dy, approx_fee


@internal
@view
def _fee(xp: uint256[N_COINS], swap: address) -> uint256:
    packed_fee_params: uint256 = Curve_3pool(swap).packed_fee_params()
    fee_params: uint256[3] = self._unpack(packed_fee_params)
    f: uint256 = self.math.reduction_coefficient(xp, fee_params[2])
    return (fee_params[0] * f + fee_params[1] * (10**18 - f)) / 10**18


@internal
@view
def _unpack(_packed: uint256) -> uint256[3]:
    """
    @notice Unpacks a uint256 into 3 integers (values must be <= 10**18)
    @param val The uint256 to unpack
    @return The unpacked uint256[3]
    """
    return [
        (_packed >> 128) & 18446744073709551615,
        (_packed >> 64) & 18446744073709551615,
        _packed & 18446744073709551615,
    ]


@internal
@view
def _calc_v2_fee(i: uint256, j: uint256, dx: uint256, swap: address) -> uint256:
    """
    f = fee_gamma / (fee_gamma + (1 - K))
    where
    K = prod(x) / (sum(x) / N)**N
    (all normalized to 1e18)
    """
    
    xp: uint256[2] = [Curve_2pool(swap).balances(0), Curve_2pool(swap).balances(1)]
    fee_gamma: uint256 = Curve_2pool(swap).fee_gamma()
    mid_fee: uint256 = Curve_2pool(swap).mid_fee()
    out_fee: uint256 = Curve_2pool(swap).out_fee()
    f: uint256 = xp[0] + xp[1]  # sum
    f = fee_gamma * 10**18 / (
        fee_gamma + 10**18 - (10**18 * 2**2) * xp[0] / f * xp[1] / f
    )
    return (mid_fee * f + out_fee * (10**18 - f)) / 10**18


@internal
@view
def is_tng(swap: address) -> bool:
    is_tng: bool = False
    if self._get_registry(swap) in [0x9335BF643C455478F8BE40fA20B5164b90215B80]:
        is_tng = True
    return is_tng




@internal
@view
def is_v2(swap: address) -> bool:
    # XXX Not exhaustive, but works with current logic
    is_v2: bool = False
    if self._get_registry(swap) in [0x5f493fEE8D67D3AE3bA730827B34126CFcA0ae94]:
        is_v2 = True
    return is_v2



