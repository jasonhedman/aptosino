#[test_only]
module aptosino::test_house {
    use std::signer;
    use aptos_framework::account;

    use aptos_framework::aptos_coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptosino::house::HouseShares;
    use aptosino::test_helpers;

    use aptosino::house;

    const INITIAL_DEPOSIT: u64 = 10_000_000;
    const MIN_BET: u64 = 1_000_000;
    const MAX_BET: u64 = 10_000_000;
    const MAX_MULTIPLIER: u64 = 20;
    const FEE_BPS: u64 = 100;
    const FEE_DIVISOR: u64 = 10_000;
    
    struct TestGame has drop {}
    

    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    fun test_init(framework: &signer, aptosino: &signer) {
        test_helpers::setup_tests(framework, aptosino, INITIAL_DEPOSIT);
        house::init(
            aptosino,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
        );
        assert!(house::get_admin_address() == signer::address_of(aptosino), 0);
        assert!(house::get_house_balance() == INITIAL_DEPOSIT, 0);
        assert!(house::get_min_bet() == MIN_BET, 0);
        assert!(house::get_max_bet() == MAX_BET, 0);
        assert!(house::get_max_multiplier() == MAX_MULTIPLIER, 0);
        assert!(house::get_house_shares_supply() == (INITIAL_DEPOSIT as u128), 0);
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
        );
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    #[expected_failure(abort_code= house::EInsufficientBalance)]
    fun test_init_not_enough_coins(framework: &signer, aptosino: &signer) {
        test_helpers::setup_tests(framework, aptosino, INITIAL_DEPOSIT);
        house::init(
            aptosino,
            INITIAL_DEPOSIT + 1,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
        );
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    fun test_admin_functions(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER);

        let new_min_bet: u64 = 2_000_000;
        house::set_min_bet(aptosino, new_min_bet);
        assert!(house::get_min_bet() == new_min_bet, 0);

        let new_max_bet: u64 = 20_000_000;
        house::set_max_bet(aptosino, new_max_bet);
        assert!(house::get_max_bet() == new_max_bet, 0);

        let new_max_multiplier: u64 = 20;
        house::set_max_multiplier(aptosino, new_max_multiplier);
        assert!(house::get_max_multiplier() == new_max_multiplier, 0);

        let new_admin_address = @0x101;
        house::set_admin(aptosino, new_admin_address);
        assert!(house::get_admin_address() == new_admin_address, 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, non_admin = @0x101)]
    #[expected_failure(abort_code= house::ESignerNotAdmin)]
    fun test_set_min_bet_not_admin(framework: &signer, aptosino: &signer, non_admin: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER);
        house::set_min_bet(non_admin, 1);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, non_admin = @0x101)]
    #[expected_failure(abort_code= house::ESignerNotAdmin)]
    fun test_set_max_bet_not_admin(framework: &signer, aptosino: &signer, non_admin: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER);
        house::set_max_bet(non_admin, 1);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, non_admin = @0x101)]
    #[expected_failure(abort_code= house::ESignerNotAdmin)]
    fun test_set_max_multiplier_not_admin(framework: &signer, aptosino: &signer, non_admin: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER);
        house::set_max_multiplier(non_admin, 1);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    fun test_approve_game(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER);
        house::approve_game(aptosino, FEE_BPS, TestGame {});
        assert!(house::is_game_approved<TestGame>(), 0);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino, non_admin = @0x101)]
    #[expected_failure(abort_code= house::ESignerNotAdmin)]
    fun test_approve_game_not_admin(framework: &signer, aptosino: &signer, non_admin: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER);
        house::approve_game(non_admin, FEE_BPS, TestGame {});
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    #[expected_failure(abort_code= house::EGameAlreadyApproved)]
    fun test_approve_game_twice(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER);
        house::approve_game(aptosino, FEE_BPS, TestGame {});
        house::approve_game(aptosino, FEE_BPS, TestGame {});
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    fun test_revoke_game(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER);
        house::approve_game(aptosino, FEE_BPS, TestGame {});
        house::revoke_game<TestGame>(aptosino);
        assert!(!house::is_game_approved<TestGame>(), 0);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino, non_admin = @0x101)]
    #[expected_failure(abort_code= house::ESignerNotAdmin)]
    fun test_revoke_game_not_admin(framework: &signer, aptosino: &signer, non_admin: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER);
        house::revoke_game<TestGame>(non_admin);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    #[expected_failure(abort_code= house::EGameNotApproved)]
    fun test_revoke_game_not_approved(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER);
        house::revoke_game<TestGame>(aptosino);
    }
    
    fun setup_with_approved_game(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER);
        house::approve_game(aptosino, FEE_BPS, TestGame {});
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    fun test_set_fee_bps(framework: &signer, aptosino: &signer) {
        setup_with_approved_game(framework, aptosino);
        let new_fee_bps: u64 = 200;
        house::set_fee_bps<TestGame>(aptosino, new_fee_bps);
        assert!(house::get_fee_bps<TestGame>() == new_fee_bps, 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, non_admin = @0x101)]
    #[expected_failure(abort_code= house::ESignerNotAdmin)]
    fun test_set_fee_bps_not_admin(framework: &signer, aptosino: &signer, non_admin: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER);
        house::set_fee_bps<TestGame>(non_admin, 1);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    fun test_bet(framework: &signer, aptosino: &signer) {
        setup_with_approved_game(framework, aptosino);
        
        let bet_amount: u64 = 1_000_000;
        let fee = test_helpers::get_fee(bet_amount, FEE_BPS, FEE_DIVISOR);
        let multiplier_numerator = 3;
        let multiplier_denominator = 2;
        
        house::test_pay_out(
            signer::address_of(aptosino),
            test_helpers::mint_coins(framework, bet_amount),
            multiplier_numerator,
            multiplier_denominator,
            TestGame {}
        );
        
        let payout = bet_amount * multiplier_numerator / multiplier_denominator - fee;
        
        assert!(house::get_house_balance() == INITIAL_DEPOSIT - payout + bet_amount, 0);
        assert!(coin::balance<AptosCoin>(signer::address_of(aptosino)) == payout, 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    #[expected_failure(abort_code= house::EBetLessThanMinBet)]
    fun test_bet_less_than_min_bet(framework: &signer, aptosino: &signer) {
        setup_with_approved_game(framework, aptosino);
        let bet_amount: u64 = MIN_BET - 1;
        let multiplier_numerator = 3;
        let multiplier_denominator = 2;
        house::test_pay_out(
            signer::address_of(aptosino),
            test_helpers::mint_coins(framework, bet_amount),
            multiplier_numerator,
            multiplier_denominator,
            TestGame {}
        );
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    #[expected_failure(abort_code= house::EBetExceedsMaxBet)]
    fun test_bet_greater_than_max_bet(framework: &signer, aptosino: &signer) {
        setup_with_approved_game(framework, aptosino);
        let bet_amount: u64 = MAX_BET + 1;
        let multiplier_numerator = 3;
        let multiplier_denominator = 2;
        house::test_pay_out(
            signer::address_of(aptosino),
            test_helpers::mint_coins(framework, bet_amount),
            multiplier_numerator,
            multiplier_denominator,
            TestGame {}
        );
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    #[expected_failure(abort_code= house::EBetExceedsMaxMultiplier)]
    fun test_bet_multiplier_greater_than_max_multiplier(framework: &signer, aptosino: &signer) {
        setup_with_approved_game(framework, aptosino);
        let bet_amount: u64 = MIN_BET;
        let multiplier_numerator = MAX_MULTIPLIER + 1;
        let multiplier_denominator = 1;
        house::test_pay_out(
            signer::address_of(aptosino),
            test_helpers::mint_coins(framework, bet_amount),
            multiplier_numerator,
            multiplier_denominator,
            TestGame {}
        );
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    fun test_bet_payout_zero(framework: &signer, aptosino: &signer) {
        setup_with_approved_game(framework, aptosino);
        let bet_amount: u64 = MIN_BET;
        let multiplier_numerator = 0;
        let multiplier_denominator = 1;
        
        let balance_before = coin::balance<AptosCoin>(signer::address_of(aptosino));
        house::test_pay_out(
            signer::address_of(aptosino),
            test_helpers::mint_coins(framework, bet_amount),
            multiplier_numerator,
            multiplier_denominator,
            TestGame {}
        );
        assert!(coin::balance<AptosCoin>(signer::address_of(aptosino)) == balance_before, 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    #[expected_failure(abort_code= house::EGameNotApproved)]
    fun test_bet_game_not_approved(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER);
        let bet_amount: u64 = MIN_BET;
        let multiplier_numerator = 3;
        let multiplier_denominator = 2;
        house::test_pay_out(
            signer::address_of(aptosino),
            test_helpers::mint_coins(framework, bet_amount),
            multiplier_numerator,
            multiplier_denominator,
            TestGame {}
        );
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    #[expected_failure(abort_code= house::EHouseInsufficientBalance)]
    fun test_bet_house_insufficient_balance(framework: &signer, aptosino: &signer) {
        setup_with_approved_game(framework, aptosino);
        let bet_amount: u64 = MAX_BET;
        let multiplier_numerator = MAX_MULTIPLIER;
        let multiplier_denominator = 1;
        house::test_pay_out(
            signer::address_of(aptosino),
            test_helpers::mint_coins(framework, bet_amount),
            multiplier_numerator,
            multiplier_denominator,
            TestGame {}
        );
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    fun test_get_deposit_and_withdraw_amounts(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER);
        
        assert!(house::get_house_shares_amount_from_deposit_amount(100) == 100, 0);
        assert!(house::get_withdraw_amount_from_shares_amount(100) == 100, 0);
        
        house::withdraw(aptosino, coin::balance<HouseShares>(signer::address_of(aptosino)));

        assert!(house::get_house_shares_amount_from_deposit_amount(100) == 100, 0);
        assert!(house::get_withdraw_amount_from_shares_amount(100) == 0, 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    fun test_deposit(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER);
        let deposit_amount: u64 = 10_000_000;
        aptos_coin::mint(framework, signer::address_of(aptosino), deposit_amount);
        house::deposit(aptosino, deposit_amount);
        assert!(house::get_house_balance() == INITIAL_DEPOSIT + deposit_amount, 0);
        assert!(house::get_house_shares_supply() == ((INITIAL_DEPOSIT + deposit_amount) as u128), 0);
        assert!(coin::balance<HouseShares>(@aptosino) == INITIAL_DEPOSIT + deposit_amount, 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    #[expected_failure(abort_code= house::EInsufficientBalance)]
    fun test_deposit_not_enough_coins(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER);
        let deposit_amount: u64 = 10_000_000;
        house::deposit(aptosino, deposit_amount);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    #[expected_failure(abort_code=house::EAmountInvalid)]
    fun test_deposit_zero(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER);
        house::deposit(aptosino, 0);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    fun test_deposit_after_bet_win(framework: &signer, aptosino: &signer) {
        setup_with_approved_game(framework, aptosino);
        
        let bet_amount: u64 = 1_000_000;
        let fee = test_helpers::get_fee(bet_amount, FEE_BPS, FEE_DIVISOR);
        let multiplier_numerator = 3;
        let multiplier_denominator = 2;
        
        house::test_pay_out(
            signer::address_of(aptosino),
            test_helpers::mint_coins(framework, bet_amount),
            multiplier_numerator,
            multiplier_denominator,
            TestGame {}
        );
        let payout = bet_amount * multiplier_numerator / multiplier_denominator - fee;
        let house_balance_before = house::get_house_balance();

        let deposit_amount: u64 = 10_000_000;
        aptos_coin::mint(framework, signer::address_of(aptosino), deposit_amount);
        house::deposit(aptosino, deposit_amount);
        assert!(house::get_house_balance() == INITIAL_DEPOSIT - payout + bet_amount + deposit_amount, 0);
        assert!(house::get_house_shares_supply() == ((INITIAL_DEPOSIT + deposit_amount * INITIAL_DEPOSIT / house_balance_before) as u128), 0);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    fun test_deposit_after_loss(framework: &signer, aptosino: &signer) {
        setup_with_approved_game(framework, aptosino);
        
        let bet_amount: u64 = 1_000_000;
        let multiplier_numerator = 0;
        let multiplier_denominator = 1;
        
        house::test_pay_out(
            signer::address_of(aptosino),
            test_helpers::mint_coins(framework, bet_amount),
            multiplier_numerator,
            multiplier_denominator,
            TestGame {}
        );
        let house_balance_before = house::get_house_balance();

        let deposit_amount: u64 = 10_000_000;
        aptos_coin::mint(framework, signer::address_of(aptosino), deposit_amount);
        house::deposit(aptosino, deposit_amount);
        assert!(house::get_house_balance() == INITIAL_DEPOSIT + bet_amount + deposit_amount, 0);
        assert!(house::get_house_shares_supply() == ((INITIAL_DEPOSIT + deposit_amount * INITIAL_DEPOSIT / house_balance_before) as u128), 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    fun test_withdraw(framework: &signer, aptosino: &signer) {
        setup_with_approved_game(framework, aptosino);
        house::withdraw(aptosino, coin::balance<HouseShares>(@aptosino));
        assert!(coin::balance<AptosCoin>(@aptosino) == INITIAL_DEPOSIT, 0);
        assert!(coin::balance<HouseShares>(@aptosino) == 0, 0)
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    #[expected_failure(abort_code=house::EAmountInvalid)]
    fun test_withdraw_zero(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER);
        house::withdraw(aptosino, 0);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    #[expected_failure(abort_code= house::EInsufficientBalance)]
    fun test_withdraw_not_enough_shares(framework: &signer, aptosino: &signer) {
        setup_with_approved_game(framework, aptosino);
        house::withdraw(aptosino, coin::balance<HouseShares>(@aptosino) + 1);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_withdraw_after_win(framework: &signer, aptosino: &signer, player: &signer) {
        setup_with_approved_game(framework, aptosino);
        
        let bet_amount: u64 = 1_000_000;
        let multiplier_numerator = 3;
        let multiplier_denominator = 2;
        
        let player_address = signer::address_of(player);
        account::create_account_for_test(player_address);
        coin::register<AptosCoin>(player);
        house::test_pay_out(
            player_address,
            test_helpers::mint_coins(framework, bet_amount),
            multiplier_numerator,
            multiplier_denominator,
            TestGame {}
        );
        
        let fee = test_helpers::get_fee(bet_amount, FEE_BPS, FEE_DIVISOR);

        house::withdraw(aptosino, coin::balance<HouseShares>(@aptosino));
        assert!(coin::balance<AptosCoin>(@aptosino) == INITIAL_DEPOSIT - bet_amount / 2 + fee, 0);
        assert!(coin::balance<HouseShares>(@aptosino) == 0, 0);
        assert!(house::get_house_balance() == 0, 0);
        assert!(house::get_house_shares_supply() == 0, 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_withdraw_after_loss(framework: &signer, aptosino: &signer, player: &signer) {
        setup_with_approved_game(framework, aptosino);

        let bet_amount: u64 = 1_000_000;
        let multiplier_numerator = 0;
        let multiplier_denominator = 1;

        let player_address = signer::address_of(player);
        account::create_account_for_test(player_address);
        coin::register<AptosCoin>(player);
        house::test_pay_out(
            player_address,
            test_helpers::mint_coins(framework, bet_amount),
            multiplier_numerator,
            multiplier_denominator,
            TestGame {}
        );
        
        house::withdraw(aptosino, coin::balance<HouseShares>(@aptosino));
        assert!(coin::balance<AptosCoin>(@aptosino) == INITIAL_DEPOSIT + bet_amount, 0);
        assert!(coin::balance<HouseShares>(@aptosino) == 0, 0);
        assert!(house::get_house_balance() == 0, 0);
        assert!(house::get_house_shares_supply() == 0, 0);
    }
}
