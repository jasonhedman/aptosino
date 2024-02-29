#[test_only]
module aptosino::test_house {
    use std::signer;
    
    use aptos_framework::aptos_coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptosino::test_helpers;

    use aptosino::house;

    const INITIAL_DEPOSIT: u64 = 10_000_000;
    const MIN_BET: u64 = 1_000_000;
    const MAX_BET: u64 = 10_000_000;
    const MAX_MULTIPLIER: u64 = 20;
    const FEE_BPS: u64 = 100;
    const FEE_DIVISOR: u64 = 10_000;
    

    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    fun test_init(framework: &signer, aptosino: &signer) {
        test_helpers::setup_tests(framework, aptosino, INITIAL_DEPOSIT);
        house::init(
            aptosino,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS,
        );
        assert!(house::get_admin_address() == signer::address_of(aptosino), 0);
        assert!(house::get_house_balance() == INITIAL_DEPOSIT, 0);
        assert!(house::get_min_bet() == MIN_BET, 0);
        assert!(house::get_max_bet() == MAX_BET, 0);
        assert!(house::get_max_multiplier() == MAX_MULTIPLIER, 0);
        assert!(house::get_fee_bps() == FEE_BPS, 0);
    }

    #[test(framework = @aptos_framework, aptosino = @0x101)]
    #[expected_failure(abort_code= house::ESignerNotDeployer)]
    fun test_init_invalid_deployer(framework: &signer, aptosino: &signer) {
        test_helpers::setup_tests(framework, aptosino, INITIAL_DEPOSIT);
        house::init(
            aptosino,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS,
        );
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    #[expected_failure(abort_code= house::EAdminInsufficientBalance)]
    fun test_init_not_enough_coins(framework: &signer, aptosino: &signer) {
        test_helpers::setup_tests(framework, aptosino, INITIAL_DEPOSIT);
        house::init(
            aptosino,
            INITIAL_DEPOSIT + 1,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS,
        );
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    fun test_deposit(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER, FEE_BPS);
        let deposit_amount: u64 = 10_000_000;
        aptos_coin::mint(framework, signer::address_of(aptosino), deposit_amount);
        house::deposit(aptosino, deposit_amount);
        assert!(house::get_house_balance() == INITIAL_DEPOSIT + deposit_amount, 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, non_admin = @0x101)]
    #[expected_failure(abort_code= house::ESignerNotAdmin)]
    fun test_deposit_not_admin(framework: &signer, aptosino: &signer, non_admin: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER, FEE_BPS);
        house::deposit(non_admin, 1);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    #[expected_failure(abort_code= house::EAdminInsufficientBalance)]
    fun test_deposit_not_enough_coins(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER, FEE_BPS);
        let deposit_amount: u64 = 10_000_000;
        house::deposit(aptosino, deposit_amount);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    fun test_admin_functions(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER, FEE_BPS);

        let new_min_bet: u64 = 2_000_000;
        house::set_min_bet(aptosino, new_min_bet);
        assert!(house::get_min_bet() == new_min_bet, 0);

        let new_max_bet: u64 = 20_000_000;
        house::set_max_bet(aptosino, new_max_bet);
        assert!(house::get_max_bet() == new_max_bet, 0);

        let new_max_multiplier: u64 = 20;
        house::set_max_multiplier(aptosino, new_max_multiplier);
        assert!(house::get_max_multiplier() == new_max_multiplier, 0);

        let new_fee_bps: u64 = 200;
        house::set_fee_bps(aptosino, new_fee_bps);
        assert!(house::get_fee_bps() == new_fee_bps, 0);
        let bet_amount: u64 = 1_000_000;
        assert!(house::get_fee_amount(bet_amount) == test_helpers::get_fee(bet_amount, new_fee_bps, FEE_DIVISOR), 0);

        let new_admin_address = @0x101;
        house::set_admin(aptosino, new_admin_address);
        assert!(house::get_admin_address() == new_admin_address, 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, non_admin = @0x101)]
    #[expected_failure(abort_code= house::ESignerNotAdmin)]
    fun test_set_min_bet_not_admin(framework: &signer, aptosino: &signer, non_admin: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER, FEE_BPS);
        house::set_min_bet(non_admin, 1);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, non_admin = @0x101)]
    #[expected_failure(abort_code= house::ESignerNotAdmin)]
    fun test_set_max_bet_not_admin(framework: &signer, aptosino: &signer, non_admin: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER, FEE_BPS);
        house::set_max_bet(non_admin, 1);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, non_admin = @0x101)]
    #[expected_failure(abort_code= house::ESignerNotAdmin)]
    fun test_set_max_multiplier_not_admin(framework: &signer, aptosino: &signer, non_admin: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER, FEE_BPS);
        house::set_max_multiplier(non_admin, 1);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, non_admin = @0x101)]
    #[expected_failure(abort_code= house::ESignerNotAdmin)]
    fun test_set_fee_bps_not_admin(framework: &signer, aptosino: &signer, non_admin: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER, FEE_BPS);
        house::set_fee_bps(non_admin, 1);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    fun test_acquire_and_release_bet_lock_max_payout(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER, FEE_BPS);
        
        let bet_amount: u64 = 1_000_000;
        let fee = test_helpers::get_fee(bet_amount, FEE_BPS, FEE_DIVISOR);
        let multiplier_numerator = 3;
        let multiplier_denominator = 2;
        
        let bet_lock = house::test_acquire_bet_lock(
            signer::address_of(aptosino), 
            test_helpers::mint_coins(framework, bet_amount), 
            multiplier_numerator,
            multiplier_denominator
        );
        
        let max_payout = house::get_max_payout(&bet_lock);
        
        assert!(max_payout == bet_amount * multiplier_numerator / multiplier_denominator - fee, 0);
        assert!(house::get_house_balance() == INITIAL_DEPOSIT - max_payout + bet_amount, 0);
        assert!(house::get_accrued_fees() == fee, 0);
        
        house::test_release_bet_lock(bet_lock, max_payout);
        
        assert!(house::get_house_balance() ==
            INITIAL_DEPOSIT - max_payout + bet_amount, 0);
        assert!(coin::balance<AptosCoin>(signer::address_of(aptosino)) == max_payout, 0);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    fun test_acquire_and_release_bet_lock_max_payout_partial_payout(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER, FEE_BPS);

        let bet_amount: u64 = 1_000_000;
        let multiplier_numerator = 3;
        let multiplier_denominator = 2;

        let bet_lock = house::test_acquire_bet_lock(
            signer::address_of(aptosino), 
            test_helpers::mint_coins(framework, bet_amount), 
            multiplier_numerator,
            multiplier_denominator
        );

        let max_payout = house::get_max_payout(&bet_lock);
        let payout_difference = 100;
        let payout = max_payout - payout_difference;

        house::test_release_bet_lock(bet_lock, payout);

        assert!(house::get_house_balance() == 
            INITIAL_DEPOSIT - max_payout + payout_difference + bet_amount, 0);
        assert!(coin::balance<AptosCoin>(signer::address_of(aptosino)) == 
            max_payout - payout_difference, 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    #[expected_failure(abort_code= house::EPayoutExceedsMaxPayout)]
    fun test_release_bet_lock_invalid_payout(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER, FEE_BPS);

        let bet_amount: u64 = 1_000_000;
        let multiplier_numerator = 3;
        let multiplier_denominator = 2;

        let bet_lock = house::test_acquire_bet_lock(
            signer::address_of(aptosino), 
            test_helpers::mint_coins(framework, bet_amount), 
            multiplier_numerator,
            multiplier_denominator
        );

        let max_payout = house::get_max_payout(&bet_lock);

        house::test_release_bet_lock(bet_lock, max_payout + 1);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    #[expected_failure(abort_code= house::EBetLessThanMinBet)]
    fun test_bet_less_than_min_bet(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER, FEE_BPS);
        let bet_amount: u64 = MIN_BET - 1;
        let multiplier_numerator = 3;
        let multiplier_denominator = 2;
        let bet_lock = house::test_acquire_bet_lock(
            signer::address_of(aptosino),
            test_helpers::mint_coins(framework, bet_amount),
            multiplier_numerator,
            multiplier_denominator
        );
        let max_payout = house::get_max_payout(&bet_lock);
        house::test_release_bet_lock(bet_lock, max_payout);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    #[expected_failure(abort_code= house::EBetExceedsMaxBet)]
    fun test_bet_greater_than_max_bet(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER, FEE_BPS);
        let bet_amount: u64 = MAX_BET + 1;
        let multiplier_numerator = 3;
        let multiplier_denominator = 2;
        let bet_lock = house::test_acquire_bet_lock(
            signer::address_of(aptosino),
            test_helpers::mint_coins(framework, bet_amount),
            multiplier_numerator,
            multiplier_denominator
        );
        let max_payout = house::get_max_payout(&bet_lock);
        house::test_release_bet_lock(bet_lock, max_payout);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    #[expected_failure(abort_code= house::EBetExceedsMaxMultiplier)]
    fun test_bet_multiplier_greater_than_max_multiplier(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER, FEE_BPS);
        let bet_amount: u64 = MIN_BET;
        let multiplier_numerator = MAX_MULTIPLIER + 1;
        let multiplier_denominator = 1;
        let bet_lock = house::test_acquire_bet_lock(
            signer::address_of(aptosino),
            test_helpers::mint_coins(framework, bet_amount),
            multiplier_numerator,
            multiplier_denominator
        );
        let max_payout = house::get_max_payout(&bet_lock);
        house::test_release_bet_lock(bet_lock, max_payout);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    #[expected_failure(abort_code= house::EBetLessThanMinMultiplier)]
    fun test_bet_multiplier_less_than_min_multiplier(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER, FEE_BPS);
        let bet_amount: u64 = MIN_BET;
        let multiplier_numerator = 2;
        let multiplier_denominator = multiplier_numerator + 1;
        let bet_lock = house::test_acquire_bet_lock(
            signer::address_of(aptosino),
            test_helpers::mint_coins(framework, bet_amount),
            multiplier_numerator,
            multiplier_denominator
        );
        let max_payout = house::get_max_payout(&bet_lock);
        house::test_release_bet_lock(bet_lock, max_payout);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    #[expected_failure(abort_code= house::EHouseInsufficientBalance)]
    fun test_house_insufficient_balance(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER, FEE_BPS);
        let bet_amount: u64 = MAX_BET;
        let multiplier_numerator = MAX_MULTIPLIER;
        let multiplier_denominator = 1;
        let bet_lock = house::test_acquire_bet_lock(
            signer::address_of(aptosino),
            test_helpers::mint_coins(framework, bet_amount),
            multiplier_numerator,
            multiplier_denominator
        );
        let max_payout = house::get_max_payout(&bet_lock);
        house::test_release_bet_lock(bet_lock, max_payout);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    fun test_withdraw_fees(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER, FEE_BPS);

        let bet_amount: u64 = 1_000_000;
        let fee = test_helpers::get_fee(bet_amount, FEE_BPS, FEE_DIVISOR);
        let multiplier_numerator = 3;
        let multiplier_denominator = 2;

        let bet_lock = house::test_acquire_bet_lock(
            signer::address_of(framework),
            test_helpers::mint_coins(framework, bet_amount),
            multiplier_numerator,
            multiplier_denominator
        );
        let max_payout = house::get_max_payout(&bet_lock);
        house::test_release_bet_lock(bet_lock, max_payout);

        house::withdraw_fees(aptosino);
        assert!(coin::balance<AptosCoin>(signer::address_of(aptosino)) == fee, 0);
    }
}
