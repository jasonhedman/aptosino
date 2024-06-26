#[test_only]
module aptosino::test_game {

    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptosino::game::resolve_game;
    use aptosino::house;
    use aptosino::game;
    use aptosino::test_helpers;

    struct TestGame has drop {}

    const INITIAL_DEPOSIT: u64 = 10_000_000;
    const MIN_BET: u64 = 1_000_000;
    const MAX_BET: u64 = 10_000_000;
    const MAX_MULTIPLIER: u64 = 20;
    const FEE_BPS: u64 = 100;
    const BET_AMOUNT: u64 = 1_000_000;
    
    fun setup_tests(framework: &signer, aptosino: &signer, player: &signer) {
        test_helpers::setup_house_with_player(
            framework,
            aptosino,
            player,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
        );
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    fun test_create_and_resolve_game_win(framework: &signer, aptosino: &signer, player: &signer) {
        setup_tests(framework, aptosino, player);
        house::approve_game(aptosino, FEE_BPS, TestGame {});
        let player_balance_before = coin::balance<AptosCoin>(@0x101);
        let game = game::create_game(player, BET_AMOUNT, TestGame {});
        assert!(game::get_player_address(&game) == @0x101, 0);
        assert!(game::get_bet_amount(&game) == BET_AMOUNT, 0);
        assert!(coin::balance<AptosCoin>(@0x101) == player_balance_before - BET_AMOUNT, 0);
        game::resolve_game(game, 2, 1, TestGame {});
        let fee = house::get_fee_amount<TestGame>(BET_AMOUNT);
        assert!(coin::balance<AptosCoin>(@0x101) == player_balance_before + BET_AMOUNT - fee, 0);
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    fun test_create_and_resolve_game_lose(framework: &signer, aptosino: &signer, player: &signer) {
        setup_tests(framework, aptosino, player);
        house::approve_game(aptosino, FEE_BPS, TestGame {});
        let player_balance_before = coin::balance<AptosCoin>(@0x101);
        let game = game::create_game(player, BET_AMOUNT, TestGame {});
        assert!(game::get_player_address(&game) == @0x101, 0);
        assert!(game::get_bet_amount(&game) == BET_AMOUNT, 0);
        assert!(coin::balance<AptosCoin>(@0x101) == player_balance_before - BET_AMOUNT, 0);
        game::resolve_game(game, 0, 1, TestGame {});
        assert!(coin::balance<AptosCoin>(@0x101) == player_balance_before - BET_AMOUNT, 0);
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    #[expected_failure(abort_code=game::EGameNotApproved)]
    fun test_create_game_not_approved(framework: &signer, aptosino: &signer, player: &signer) {
        setup_tests(framework, aptosino, player);
        let game = game::create_game(player, BET_AMOUNT, TestGame {});
        resolve_game(game, 2, 1, TestGame {})
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    #[expected_failure(abort_code=game::EBetAmountIsZero)]
    fun test_create_game_bet_amount_is_zero(framework: &signer, aptosino: &signer, player: &signer) {
        setup_tests(framework, aptosino, player);
        house::approve_game(aptosino, FEE_BPS, TestGame {});
        let game = game::create_game(player, 0, TestGame {});
        resolve_game(game, 2, 1, TestGame {})
    }

    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    #[expected_failure(abort_code=game::EBetAmountLessThanMinimum)]
    fun test_create_game_bet_amount_less_than_min(framework: &signer, aptosino: &signer, player: &signer) {
        setup_tests(framework, aptosino, player);
        house::approve_game(aptosino, FEE_BPS, TestGame {});
        let game = game::create_game(player, MIN_BET - 1, TestGame {});
        resolve_game(game, 2, 1, TestGame {})
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    #[expected_failure(abort_code=game::EBetAmountGreaterThanMaximum)]
    fun test_create_game_bet_amount_greater_than_max(framework: &signer, aptosino: &signer, player: &signer) {
        setup_tests(framework, aptosino, player);
        house::approve_game(aptosino, FEE_BPS, TestGame {});
        let game = game::create_game(player, MAX_BET + 1, TestGame {});
        resolve_game(game, 2, 1, TestGame {})
    }
    
    #[test(framework=@aptos_framework, aptosino=@aptosino, player=@0x101)]
    #[expected_failure(abort_code=game::EPlayerInsufficientBalance)]
    fun test_create_game_insufficient_balance(framework: &signer, aptosino: &signer, player: &signer) {
        setup_tests(framework, aptosino, player);
        house::approve_game(aptosino, FEE_BPS, TestGame {});
        coin::transfer<AptosCoin>(player, @aptosino, 100);
        let game = game::create_game(player, MAX_BET, TestGame {});
        resolve_game(game, 2, 1, TestGame {})
    }
}
