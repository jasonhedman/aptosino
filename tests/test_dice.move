#[test_only]
module aptosino::test_dice {
    
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::aptos_coin;

    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptosino::test_helpers;

    use aptosino::house;
    use aptosino::dice;

    const INITIAL_DEPOSIT: u64 = 10_000_000;
    const MIN_BET: u64 = 1_000_000;
    const MAX_BET: u64 = 10_000_000;
    const MAX_MULTIPLIER: u64 = 20;
    const FEE_BPS: u64 = 100;
    const FEE_DIVISOR: u64 = 10_000;
    const BET_AMOUNT: u64 = 1_000_000;
    
    fun setup_house_with_player(framework: &signer, aptosino: &signer, player: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER, FEE_BPS);
        account::create_account_for_test(signer::address_of(player));
        coin::register<AptosCoin>(player);
        aptos_coin::mint(framework, signer::address_of(player), MAX_BET + 1);
    }
    
    fun get_fee(amount: u64): u64 { amount * FEE_BPS / FEE_DIVISOR }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_roll_dice_win_multiplier_2(framework: &signer, aptosino: &signer, player: &signer) {
        setup_house_with_player(framework, aptosino, player);
        
        let house_balance = house::get_house_balance();
        let user_balance = coin::balance<AptosCoin>(signer::address_of(player));
        let fee = get_fee(BET_AMOUNT);
        
        dice::test_spin_wheel(player, BET_AMOUNT, 2, 0, 0);
        
        let house_balance_change = house_balance - house::get_house_balance();
        assert!(house_balance_change == BET_AMOUNT - fee , 0);
        
        let user_balance_change = coin::balance<AptosCoin>(signer::address_of(player)) - user_balance;
        assert!(user_balance_change == BET_AMOUNT - fee, 0);
        
        assert!(house::get_accrued_fees() == fee, 0);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_roll_dice_lose_multiplier_2(framework: &signer, aptosino: &signer, player: &signer) {
        setup_house_with_player(framework, aptosino, player);
        
        let house_balance = house::get_house_balance();
        let user_balance = coin::balance<AptosCoin>(signer::address_of(player));
        let fee = get_fee(BET_AMOUNT);
        
        dice::test_spin_wheel(player, BET_AMOUNT, 2, 0, 1);
        
        let house_balance_change = house::get_house_balance() - house_balance;
        assert!(house_balance_change == BET_AMOUNT, 0);
        
        let user_balance_change = user_balance - coin::balance<AptosCoin>(signer::address_of(player));
        assert!(user_balance_change == BET_AMOUNT, 0);
        
        assert!(house::get_accrued_fees() == fee, 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_roll_dice_win_multiplier_4(framework: &signer, aptosino: &signer, player: &signer) {
        setup_house_with_player(framework, aptosino, player);

        let house_balance = house::get_house_balance();
        let user_balance = coin::balance<AptosCoin>(signer::address_of(player));
        let fee = get_fee(BET_AMOUNT);
        
        let multiplier = 4;

        dice::test_spin_wheel(player, BET_AMOUNT, multiplier, 0, 0);

        let house_balance_change = house_balance - house::get_house_balance();
        assert!(house_balance_change == BET_AMOUNT * (multiplier - 1) - fee , 0);

        let user_balance_change = coin::balance<AptosCoin>(signer::address_of(player)) - user_balance;
        assert!(user_balance_change == BET_AMOUNT * (multiplier - 1) - fee, 0);

        assert!(house::get_accrued_fees() == fee, 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_roll_dice_lose_multiplier_4(framework: &signer, aptosino: &signer, player: &signer) {
        setup_house_with_player(framework, aptosino, player);

        let house_balance = house::get_house_balance();
        let user_balance = coin::balance<AptosCoin>(signer::address_of(player));
        let fee = get_fee(BET_AMOUNT);
        
        let multiplier = 4;

        dice::test_spin_wheel(player, BET_AMOUNT, multiplier, 0, 1);

        let house_balance_change = house::get_house_balance() - house_balance;
        assert!(house_balance_change == BET_AMOUNT, 0);

        let user_balance_change = user_balance - coin::balance<AptosCoin>(signer::address_of(player));
        assert!(user_balance_change == BET_AMOUNT, 0);

        assert!(house::get_accrued_fees() == fee, 0);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    #[expected_failure(abort_code= dice::EPlayerInsufficientBalance)]
    fun test_roll_dice_insufficient_balance(framework: &signer, aptosino: &signer, player: &signer) {
        setup_house_with_player(framework, aptosino, player);
        coin::transfer<AptosCoin>(player, signer::address_of(aptosino), MAX_BET + 1);
        dice::test_spin_wheel(player, MIN_BET, 2, 0, 0);
    }


    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    #[expected_failure(abort_code= dice::EPredictedOutcomeGreaterThanMaxOutcome)]
    fun test_roll_dice_prediction_invalid(framework: &signer, aptosino: &signer, player: &signer) {
        setup_house_with_player(framework, aptosino, player);
        dice::test_spin_wheel(player, BET_AMOUNT, 2, 2, 0);
    }

    
    #[test(framework = @aptos_framework, aptosino = @aptosino, non_admin = @0x101)]
    fun test_spin_entry(framework: &signer, aptosino: &signer, non_admin: &signer) {
        setup_house_with_player(framework, aptosino, non_admin);
        dice::roll_dice(non_admin, BET_AMOUNT, 2, 0);
    }
}
