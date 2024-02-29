#[test_only]
module aptosino::test_roulette {
    use std::signer;
    use std::vector;

    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptosino::test_helpers;

    use aptosino::house;
    use aptosino::roulette;

    const INITIAL_DEPOSIT: u64 = 1_000_000_000_000;
    const MIN_BET: u64 = 1_000_000;
    const MAX_BET: u64 = 10_000_000;
    const MAX_MULTIPLIER: u64 = 20;
    const FEE_BPS: u64 = 100;
    const FEE_DIVISOR: u64 = 10_000;
    const BET_AMOUNT: u64 = 1_000_000;
    
    const NUM_SLOTS: u8 = 36;
    
    fun get_predicted_outcome(num_slots: u8): vector<u8> {
        let predicted_outcome: vector<u8> = vector::empty();
        let i: u8 = 0;
        while (i < num_slots) {
            vector::push_back(&mut predicted_outcome, i);
            i = i + 1;
        };
        predicted_outcome
    }
    
    fun get_predicted_outcomes(num_slots_vec: vector<u8>): vector<vector<u8>> {
        let predicted_outcomes: vector<vector<u8>> = vector::empty();
        vector::for_each(num_slots_vec, |num_slots| {
            vector::push_back(&mut predicted_outcomes, get_predicted_outcome(num_slots));
        });
        predicted_outcomes
    }
    
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
        
        let payout = roulette::get_payout(BET_AMOUNT, get_predicted_outcome(18));
        assert!(payout == BET_AMOUNT * 2 - fee, 0);
        
        let payout = roulette::get_payout(BET_AMOUNT, get_predicted_outcome(6));
        assert!(payout == BET_AMOUNT * 6 - fee, 0);
        
        let payout = roulette::get_payout(BET_AMOUNT, get_predicted_outcome(1));
        assert!(payout == BET_AMOUNT * 36 - fee, 0);
        
        let payout = roulette::get_payout(BET_AMOUNT, get_predicted_outcome(37));
        assert!(payout == 0, 0);
    }
    
    fun spin_test(
        framework: &signer, 
        aptosino: &signer, 
        player: &signer, 
        bet_amounts: vector<u64>, 
        predicted_outcomes: vector<vector<u8>>, 
        result: u8
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

        let house_balance = house::get_house_balance();
        let user_balance = coin::balance<AptosCoin>(signer::address_of(player));

        roulette::test_spin_wheel(player, bet_amounts, predicted_outcomes, result);
        
        let new_house_balance = house::get_house_balance();
        let new_user_balance = coin::balance<AptosCoin>(signer::address_of(player));
        
        if(new_house_balance < house_balance) {
            return (house_balance - new_house_balance, new_user_balance - user_balance)
        } else {
            return (new_house_balance - house_balance, user_balance - new_user_balance)
        }
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_spin_one_bet_win(framework: &signer, aptosino: &signer, player: &signer) {
        let bet_amounts: vector<u64> = vector[BET_AMOUNT];
        let predicted_outcomes = get_predicted_outcomes(vector[6]);
        let (house_balance_change, user_balance_change) = spin_test(
            framework,
            aptosino,
            player,
            bet_amounts,
            predicted_outcomes,
            0
        );
        let fee = test_helpers::get_fee(BET_AMOUNT, FEE_BPS, FEE_DIVISOR);
        let payout = roulette::get_payout(BET_AMOUNT, *vector::borrow(&predicted_outcomes, 0));
        
        assert!(house_balance_change == payout - BET_AMOUNT, 0);
        assert!(user_balance_change == payout - BET_AMOUNT, 0);
        assert!(house::get_accrued_fees() == fee, 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_spin_one_bet_lose(framework: &signer, aptosino: &signer, player: &signer) {
        let (house_balance_change, user_balance_change) = spin_test(
            framework,
            aptosino,
            player,
            vector[BET_AMOUNT],
            get_predicted_outcomes(vector[6]),
            6
        );
        assert!(house_balance_change == BET_AMOUNT, 0);
        assert!(user_balance_change == BET_AMOUNT, 0);
        assert!(house::get_accrued_fees() == test_helpers::get_fee(BET_AMOUNT, FEE_BPS, FEE_DIVISOR), 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_spin_wheel_one_bet_wins(framework: &signer, aptosino: &signer, player: &signer) {
        let bet_amounts: vector<u64> = vector[BET_AMOUNT, BET_AMOUNT];
        let total_bet_amount = BET_AMOUNT * 2;
        let bet_1_slots = 6;
        let bet_2_slots = bet_1_slots + 6;
        let predicted_outcomes = get_predicted_outcomes(vector[bet_1_slots, bet_2_slots]);
        let (house_balance_change, user_balance_change) = spin_test(
            framework,
            aptosino,
            player,
            bet_amounts,
            predicted_outcomes,
            bet_2_slots - 1
        );
        let payout_2 = roulette::get_payout(BET_AMOUNT, *vector::borrow(&predicted_outcomes, 1));
        
        assert!(house_balance_change == payout_2 - total_bet_amount, 0);
        assert!(user_balance_change == payout_2 - total_bet_amount, 0);
        assert!(house::get_accrued_fees() == house::get_fee_amount(total_bet_amount), 0);
        
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    #[expected_failure(abort_code= roulette::EPlayerInsufficientBalance)]
    fun test_spin_wheel_insufficient_balance(framework: &signer, aptosino: &signer, player: &signer) {
        spin_test(
            framework,
            aptosino,
            player,
            vector[MAX_BET, MAX_BET],
            get_predicted_outcomes(vector[6, 2]),
            0
        );
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    #[expected_failure(abort_code= roulette::ENumberOfBetsDoesNotMatchNumberOfPredictedOutcomes)]
    fun test_spin_wheel_num_predictions_not_num_bets(framework: &signer, aptosino: &signer, player: &signer) {
        spin_test(
            framework,
            aptosino,
            player,
            vector[BET_AMOUNT, BET_AMOUNT], 
            get_predicted_outcomes(vector[1]), 
            0
        );
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    #[expected_failure(abort_code= roulette::ENumberOfBetsIsZero)]
    fun test_spin_wheel_bet_amount_empty(framework: &signer, aptosino: &signer, player: &signer) {
        spin_test(
            framework,
            aptosino,
            player,
            vector[], 
            vector[], 
            0
        );
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    #[expected_failure(abort_code= roulette::EBetAmountIsZero)]
    fun test_spin_wheel_bet_amount_zero(framework: &signer, aptosino: &signer, player: &signer) {
        spin_test(
            framework,
            aptosino,
            player,
            vector[0], 
            get_predicted_outcomes(vector[1]), 
            0
        );
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    #[expected_failure(abort_code= roulette::ENumberOfPredictedOutcomesIsZero)]
    fun test_spin_wheel_prediction_empty(framework: &signer, aptosino: &signer, player: &signer) {
        spin_test(
            framework,
            aptosino,
            player,
            vector[BET_AMOUNT], 
            get_predicted_outcomes(vector[0]),
            0
        );
    }
    
    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    #[expected_failure(abort_code= roulette::EPredictedOutcomeOutOfRange)]
    fun test_spin_wheel_prediction_invalid(framework: &signer, aptosino: &signer, player: &signer) {
        spin_test(
            framework,
            aptosino,
            player,
            vector[BET_AMOUNT],
            vector[vector[NUM_SLOTS]],
            0
        );
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_spin_entry(framework: &signer, aptosino: &signer, player: &signer) {
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
        
        let bet_amounts: vector<u64> = vector[BET_AMOUNT];
        
        let predicted_outcomes: vector<vector<u8>> = vector[get_predicted_outcome(6)];
        
        roulette::spin_wheel(player, bet_amounts, predicted_outcomes);
    }
}
