#[test_only]
module aptosino::test_game {
    use aptosino::game;
    use aptosino::test_helpers;

    use aptosino::house;

    const INITIAL_DEPOSIT: u64 = 10_000_000;
    const MIN_BET: u64 = 1_000_000;
    const MAX_BET: u64 = 10_000_000;
    const MAX_MULTIPLIER: u64 = 20;
    const FEE_BPS: u64 = 100;
    const FEE_DIVISOR: u64 = 10_000;
    const BET_AMOUNT: u64 = 1_000_000;
    
    struct TestGame has drop {}
    
    #[test(framework=@aptos_framework, aptosino=@aptosino)]
    fun test_approve_game(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(framework, aptosino, INITIAL_DEPOSIT, MIN_BET, MAX_BET, MAX_MULTIPLIER, FEE_BPS);
        game::approve_game(aptosino, TestGame {});
        assert!(house::is_game_approved<TestGame>(), 0);
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    fun test_bet(framework: &signer, aptosino: &signer, player: &signer) {
        test_helpers::setup_house_with_player(
            framework, 
            aptosino, 
            player, 
            INITIAL_DEPOSIT, 
            MIN_BET, 
            MAX_BET, 
            MAX_MULTIPLIER,
            FEE_BPS
        );
        game::approve_game(aptosino, TestGame {});
        let multiplier_numerator = 3;
        let multiplier_denominator = 2;
        let bet_lock = game::acquire_bet_lock(
            player,
            BET_AMOUNT,
            multiplier_numerator,
            multiplier_denominator,
            TestGame {}
        );
        game::release_bet_lock(bet_lock, 0);
    }

    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    #[expected_failure(abort_code=game::EPlayerInsufficientBalance)]
    fun test_bet_insufficient_balance(framework: &signer, aptosino: &signer, player: &signer) {
        test_helpers::setup_house_with_player(
            framework,
            aptosino,
            player,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS
        );
        game::approve_game(aptosino, TestGame {});
        let multiplier_numerator = 3;
        let multiplier_denominator = 2;
        let bet_lock = game::acquire_bet_lock(
            player,
            MAX_BET + 2,
            multiplier_numerator,
            multiplier_denominator,
            TestGame {}
        );
        game::release_bet_lock(bet_lock, 0);
    }
}
