import pytest, random

# XXX Ape does not support strategy testing
# XXX Run through exchange to check against actual amounts

def test_random_pool_get_dx_works(views, metaregistry):
    max_val = metaregistry.pool_count()

    for i in range(10):
        value = random.randint(0, max_val-1) 

        pool = metaregistry.pool_list(value)
        dec = metaregistry.get_decimals(pool)[1]
        n = metaregistry.get_n_coins(pool)

        if metaregistry.get_balances(pool)[1] < 10 ** 18:
            # Too few coins to get a meaningful result
            return

        if metaregistry.get_balances(pool)[0] < 10 ** 18:
            # Too few coins to get a meaningful result
            return


        assert views.get_dx(1, 0, 10 ** dec, pool) > 0
        assert views.get_dy(1, 0, 10 ** dec, pool) > 0

