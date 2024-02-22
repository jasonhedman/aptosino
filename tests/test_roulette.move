#[test_only]
module aptosino::test_roulette {
    
    use std::signer;

    use aptos_std::crypto_algebra::enable_cryptography_algebra_natives;

    use aptos_framework::account;
    use aptos_framework::stake;
    use aptos_framework::aptos_coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::randomness;
    use aptosino::roulette::get_accrued_fees;

    use aptosino::roulette;
    
    const INITIAL_DEPOSIT: u64 = 10_000_000;
    const MIN_BET: u64 = 1_000_000;
    const MAX_BET: u64 = 10_000_000;
    const MAX_MULTIPLIER: u64 = 20;
    const FEE_BPS: u64 = 100;
    const FEE_DIVISOR: u64 = 10_000;
    const BET_AMOUNT: u64 = 1_000_000;
    
    fun setup_tests(framework: &signer, aptosino: &signer) {
        enable_cryptography_algebra_natives(framework);
        stake::initialize_for_test(framework);
        randomness::initialize_for_testing(framework);
        account::create_account_for_test(signer::address_of(aptosino));
        coin::register<AptosCoin>(aptosino);
        aptos_coin::mint(framework, signer::address_of(aptosino), INITIAL_DEPOSIT);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    fun test_init(framework: &signer, aptosino: &signer) {
        setup_tests(framework, aptosino);
        roulette::init(
            aptosino,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS,
        );
        assert!(roulette::get_admin_address() == signer::address_of(aptosino), 0);
        assert!(roulette::get_house_balance() == INITIAL_DEPOSIT, 0);
        assert!(roulette::get_min_bet() == MIN_BET, 0);
        assert!(roulette::get_max_bet() == MAX_BET, 0);
        assert!(roulette::get_max_multiplier() == MAX_MULTIPLIER, 0);
        assert!(roulette::get_fee_bps() == FEE_BPS, 0);
    }
    
    #[test(framework = @aptos_framework, aptosino = @0x101)]
    #[expected_failure(abort_code=roulette::ESignerNotDeployer)]
    fun test_init_invalid_deployer(framework: &signer, aptosino: &signer) {
        setup_tests(framework, aptosino);
        roulette::init(
            aptosino,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS,
        );  
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    #[expected_failure(abort_code=roulette::EAdminInsufficientBalance)]
    fun test_init_not_enough_coins(framework: &signer, aptosino: &signer) {
        setup_tests(framework, aptosino);
        roulette::init(
            aptosino,
            INITIAL_DEPOSIT + 1,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS,
        );
    }
    
    fun setup_roulette(framework: &signer, aptosino: &signer) {
        setup_tests(framework, aptosino);
        roulette::init(
            aptosino,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS,
        );
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    fun test_deposit(framework: &signer, aptosino: &signer) {
        setup_roulette(framework, aptosino);
        let deposit_amount: u64 = 10_000_000;
        aptos_coin::mint(framework, signer::address_of(aptosino), deposit_amount);
        roulette::deposit(aptosino, deposit_amount);
        assert!(roulette::get_house_balance() == INITIAL_DEPOSIT + deposit_amount, 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, non_admin = @0x101)]
    #[expected_failure(abort_code=roulette::ESignerNotAdmin)]
    fun test_deposit_not_admin(framework: &signer, aptosino: &signer, non_admin: &signer) {
        setup_roulette(framework, aptosino);
        roulette::deposit(non_admin, 1);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    #[expected_failure(abort_code=roulette::EAdminInsufficientBalance)]
    fun test_deposit_not_enough_coins(framework: &signer, aptosino: &signer) {
        setup_roulette(framework, aptosino);
        let deposit_amount: u64 = 10_000_000;
        roulette::deposit(aptosino, deposit_amount);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    fun test_admin_functions(framework: &signer, aptosino: &signer) {
        setup_roulette(framework, aptosino);
        
        let new_min_bet: u64 = 2_000_000;
        roulette::set_min_bet(aptosino, new_min_bet);
        assert!(roulette::get_min_bet() == new_min_bet, 0);
        
        let new_max_bet: u64 = 20_000_000;
        roulette::set_max_bet(aptosino, new_max_bet);
        assert!(roulette::get_max_bet() == new_max_bet, 0);
        
        let new_max_multiplier: u64 = 20;
        roulette::set_max_multiplier(aptosino, new_max_multiplier);
        assert!(roulette::get_max_multiplier() == new_max_multiplier, 0);
        
        let new_fee_bps: u64 = 200;
        roulette::set_fee_bps(aptosino, new_fee_bps);
        assert!(roulette::get_fee_bps() == new_fee_bps, 0);
        
        let new_admin_address = @0x101;
        roulette::set_admin(aptosino, new_admin_address);
        assert!(roulette::get_admin_address() == new_admin_address, 0);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino, non_admin = @0x101)]
    #[expected_failure(abort_code=roulette::ESignerNotAdmin)]
    fun test_set_min_bet_not_admin(framework: &signer, aptosino: &signer, non_admin: &signer) {
        setup_roulette(framework, aptosino);
        roulette::set_min_bet(non_admin, 1);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino, non_admin = @0x101)]
    #[expected_failure(abort_code=roulette::ESignerNotAdmin)]
    fun test_set_max_bet_not_admin(framework: &signer, aptosino: &signer, non_admin: &signer) {
        setup_roulette(framework, aptosino);
        roulette::set_max_bet(non_admin, 1);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino, non_admin = @0x101)]
    #[expected_failure(abort_code=roulette::ESignerNotAdmin)]
    fun test_set_max_multiplier_not_admin(framework: &signer, aptosino: &signer, non_admin: &signer) {
        setup_roulette(framework, aptosino);
        roulette::set_max_multiplier(non_admin, 1);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino, non_admin = @0x101)]
    #[expected_failure(abort_code=roulette::ESignerNotAdmin)]
    fun test_set_fee_bps_not_admin(framework: &signer, aptosino: &signer, non_admin: &signer) {
        setup_roulette(framework, aptosino);
        roulette::set_fee_bps(non_admin, 1);
    }
    
    fun setup_roulette_with_player(framework: &signer, aptosino: &signer, player: &signer) {
        setup_roulette(framework, aptosino);
        account::create_account_for_test(signer::address_of(player));
        coin::register<AptosCoin>(player);
        aptos_coin::mint(framework, signer::address_of(player), MAX_BET + 1);
    }
    
    fun get_fee(amount: u64): u64 { amount * FEE_BPS / FEE_DIVISOR }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_spin_wheel_win(framework: &signer, aptosino: &signer, player: &signer) {
        setup_roulette_with_player(framework, aptosino, player);
        
        let house_balance = roulette::get_house_balance();
        let user_balance = coin::balance<AptosCoin>(signer::address_of(player));
        let fee = get_fee(BET_AMOUNT);
        
        roulette::test_spin_wheel(player, BET_AMOUNT, 2, 0, 0);
        
        let house_balance_change = house_balance - roulette::get_house_balance();
        assert!(house_balance_change == BET_AMOUNT - fee , 0);
        
        let user_balance_change = coin::balance<AptosCoin>(signer::address_of(player)) - user_balance;
        assert!(user_balance_change == BET_AMOUNT - fee, 0);
        
        assert!(get_accrued_fees() == fee, 0);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_spin_wheel_lose(framework: &signer, aptosino: &signer, player: &signer) {
        setup_roulette_with_player(framework, aptosino, player);
        
        let house_balance = roulette::get_house_balance();
        let user_balance = coin::balance<AptosCoin>(signer::address_of(player));
        let fee = get_fee(BET_AMOUNT);
        
        roulette::test_spin_wheel(player, BET_AMOUNT, 2, 0, 1);
        
        let house_balance_change = roulette::get_house_balance() - house_balance;
        assert!(house_balance_change == BET_AMOUNT, 0);
        
        let user_balance_change = user_balance - coin::balance<AptosCoin>(signer::address_of(player));
        assert!(user_balance_change == BET_AMOUNT, 0);
        
        assert!(get_accrued_fees() == fee, 0);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    #[expected_failure(abort_code=roulette::EPlayerInsufficientBalance)]
    fun test_spin_wheel_insufficient_balance(framework: &signer, aptosino: &signer, player: &signer) {
        setup_roulette_with_player(framework, aptosino, player);
        coin::transfer<AptosCoin>(player, signer::address_of(aptosino), MAX_BET + 1);
        roulette::test_spin_wheel(player, MIN_BET, 2, 0, 0);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    #[expected_failure(abort_code=roulette::EBetLessThanMinBet)]
    fun test_spin_wheel_bet_less_than_min_bet(framework: &signer, aptosino: &signer, player: &signer) {
        setup_roulette_with_player(framework, aptosino, player);
        roulette::test_spin_wheel(player, MIN_BET - 1, 2, 0, 0);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    #[expected_failure(abort_code=roulette::EBetExceedsMaxBet)]
    fun test_spin_wheel_bet_greater_than_max_bet(framework: &signer, aptosino: &signer, player: &signer) {
        setup_roulette_with_player(framework, aptosino, player);
        roulette::test_spin_wheel(player, MAX_BET + 1, 2, 0, 0);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    #[expected_failure(abort_code=roulette::EBetExceedsMaxMultiplier)]
    fun test_spin_wheel_multiplier_greater_than_max_multiplier(framework: &signer, aptosino: &signer, player: &signer) {
        setup_roulette_with_player(framework, aptosino, player);
        roulette::test_spin_wheel(player, BET_AMOUNT, MAX_MULTIPLIER + 1, 0, 0);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    #[expected_failure(abort_code=roulette::EBetLessThanMinMultiplier)]
    fun test_spin_wheel_multiplier_less_than_min_multiplier(framework: &signer, aptosino: &signer, player: &signer) {
        setup_roulette_with_player(framework, aptosino, player);
        roulette::test_spin_wheel(player, BET_AMOUNT, 1, 0, 0);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    #[expected_failure(abort_code=roulette::EPredictedOutcomeGreaterThanMaxOutcome)]
    fun test_spin_wheel_prediction_invalid(framework: &signer, aptosino: &signer, player: &signer) {
        setup_roulette_with_player(framework, aptosino, player);
        roulette::test_spin_wheel(player, BET_AMOUNT, 2, 2, 0);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    #[expected_failure(abort_code=roulette::EHouseInsufficientBalance)]
    fun test_house_insufficient_balance(framework: &signer, aptosino: &signer, player: &signer) {
        setup_roulette_with_player(framework, aptosino, player);
        roulette::test_spin_wheel(player, BET_AMOUNT, MAX_MULTIPLIER - 1, 0, 0);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_withdraw_fees(framework: &signer, aptosino: &signer, player: &signer) {
        setup_roulette_with_player(framework, aptosino, player);
        roulette::test_spin_wheel(player, BET_AMOUNT, 2, 0, 0);
        let accrued_fees = get_accrued_fees();
        roulette::withdraw_fees(aptosino);
        assert!(coin::balance<AptosCoin>(signer::address_of(aptosino)) == accrued_fees, 0);
        assert!(get_accrued_fees() == 0, 0);
        assert!(roulette::get_house_balance() == INITIAL_DEPOSIT - BET_AMOUNT, 0);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino, non_admin = @0x101)]
    fun test_spin_entry(framework: &signer, aptosino: &signer, non_admin: &signer) {
        setup_roulette_with_player(framework, aptosino, non_admin);
        roulette::spin_wheel(non_admin, BET_AMOUNT, 2, 0);
    }
}
