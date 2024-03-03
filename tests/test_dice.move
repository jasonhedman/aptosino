#[test_only]
module aptosino::test_dice {
    
    use std::signer;

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
    
    #[test(framework = @aptos_framework, aptosino = @aptosino)]
    fun test_get_payout(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(
            framework,
            aptosino,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS,
        );
        let fee = test_helpers::get_fee(BET_AMOUNT, FEE_BPS, FEE_DIVISOR);
        
        let payout = dice::get_payout(BET_AMOUNT, 100, 50);
        assert!(payout == BET_AMOUNT * 2 - fee, 0);
        
        let payout = dice::get_payout(BET_AMOUNT, 100, 1);
        assert!(payout == BET_AMOUNT * 100 - fee, 0);
        
        let payout = dice::get_payout(BET_AMOUNT, 100, 75);
        assert!(payout == BET_AMOUNT * 4 / 3 - fee, 0);
        
        let payout = dice::get_payout(BET_AMOUNT, 100, 100);
        assert!(payout == 0, 0);
    }

    fun roll_test(
        framework: &signer,
        aptosino: &signer,
        player: &signer,
        bet_amount: u64,
        max_outcome: u64,
        predicted_outcome: u64,
        result: u64
    ): (u64, u64) {
        test_helpers::setup_house_with_player(
            framework,
            aptosino,
            player,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS,
        );

        dice::approve_game(aptosino);

        let house_balance = house::get_house_balance();
        let user_balance = coin::balance<AptosCoin>(signer::address_of(player));

        dice::test_roll_dice(player, bet_amount, max_outcome, predicted_outcome, result);

        let new_house_balance = house::get_house_balance();
        let new_user_balance = coin::balance<AptosCoin>(signer::address_of(player));

        if(new_house_balance < house_balance) {
            return (house_balance - new_house_balance, new_user_balance - user_balance)
        } else {
            return (new_house_balance - house_balance, user_balance - new_user_balance)
        }
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_roll_dice_win(framework: &signer, aptosino: &signer, player: &signer) {
        let max_outcome = 100;
        let predicted_outcome = 50;
        let (house_balance_change, user_balance_change) = roll_test(
            framework,
            aptosino,
            player,
            BET_AMOUNT,
            max_outcome,
            predicted_outcome,
            0
        );
        let fee = test_helpers::get_fee(BET_AMOUNT, FEE_BPS, FEE_DIVISOR);
        let payout = dice::get_payout(BET_AMOUNT, max_outcome, predicted_outcome);
        
        assert!(house_balance_change == payout - BET_AMOUNT, 0);
        assert!(user_balance_change == payout - BET_AMOUNT, 0);
        assert!(house::get_accrued_fees() == fee, 0);
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_roll_dice_lose(framework: &signer, aptosino: &signer, player: &signer) {
        let max_outcome = 100;
        let predicted_outcome = 50;
        let (house_balance_change, user_balance_change) = roll_test(
            framework,
            aptosino,
            player,
            BET_AMOUNT,
            max_outcome,
            predicted_outcome,
            max_outcome - 1,
        );
        let fee = test_helpers::get_fee(BET_AMOUNT, FEE_BPS, FEE_DIVISOR);
        
        assert!(house_balance_change == BET_AMOUNT, 0);
        assert!(user_balance_change == BET_AMOUNT, 0);
        assert!(house::get_accrued_fees() == fee, 0);
    }

    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    #[expected_failure(abort_code=dice::EPlayerInsufficientBalance)]
    fun test_roll_insufficient_balance(framework: &signer, aptosino: &signer, player: &signer) {
        roll_test(
            framework,
            aptosino,
            player,
            MAX_BET + 2,
            100,
            50,
            0,
        );
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    #[expected_failure(abort_code= dice::EPredictedOutcomeInvalid)]
    fun test_roll_dice_prediction_greater_than_maximum(framework: &signer, aptosino: &signer, player: &signer) {
        roll_test(
            framework,
            aptosino,
            player,
            BET_AMOUNT,
            100,
            100,
            0
        );
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    #[expected_failure(abort_code= dice::EPredictedOutcomeInvalid)]
    fun test_roll_dice_prediction_zero(framework: &signer, aptosino: &signer, player: &signer) {
        roll_test(
            framework,
            aptosino,
            player,
            BET_AMOUNT,
            100,
            0,
            0
        );
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_roll_entry(framework: &signer, aptosino: &signer, player: &signer) {
        test_helpers::setup_house_with_player(
            framework,
            aptosino,
            player,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS,
        );
        dice::approve_game(aptosino);
        dice::roll_dice(player, BET_AMOUNT, 2, 1);
    }
}
