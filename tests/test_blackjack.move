#[test_only]
module aptosino::test_blackjack {

    use std::signer;
    use std::vector;

    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    
    use aptosino::test_helpers;
    use aptosino::house;
    use aptosino::blackjack;

    const INITIAL_DEPOSIT: u64 = 10_000_000;
    const MIN_BET: u64 = 1_000_000;
    const MAX_BET: u64 = 10_000_000;
    const MAX_MULTIPLIER: u64 = 20;
    const FEE_BPS: u64 = 100;
    const FEE_DIVISOR: u64 = 10_000;
    const BET_AMOUNT: u64 = 1_000_000;

    fun setup_blackjack(framework: &signer, aptosino: &signer, player: &signer) {
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
        blackjack::approve_game(aptosino);
        blackjack::init(aptosino);
    }

    #[test]
    fun test_calculate_hand_value_no_ace() {
        let i = 2;
        while (i < 14) {
            let j = 2;
            while (j < 14) {
                let hand = vector[vector[i, 0], vector[j, 0]];
                let card_1_value = if(i > 10) { 10 } else { i };
                let card_2_value = if(j > 10) { 10 } else { j };
                let expected_value = if(card_1_value + card_2_value > 21) { 0 } else { card_1_value + card_2_value };
                assert!(blackjack::calculate_hand_value_no_ace(hand) == expected_value, 0);
                j = j + 1;
            };
            i = i + 1;
        };
    }

    #[test]
    fun test_calculate_hand_value_with_ace() {
        let hand_1 = vector[vector[1, 0], vector[2, 0]];
        assert!(blackjack::calculate_hand_value_with_ace(hand_1) == 13, 0);

        let hand_2 = vector[vector[1, 0], vector[1, 0]];
        assert!(blackjack::calculate_hand_value_with_ace(hand_2) == 12, 0);

        let hand_3 = vector[vector[1, 0], vector[1, 0], vector[1, 0]];
        assert!(blackjack::calculate_hand_value_with_ace(hand_3) == 13, 0);

        let hand_5 = vector[vector[1, 0], vector[1, 0], vector[11, 0]];
        assert!(blackjack::calculate_hand_value_with_ace(hand_5) == 12, 0);

        let hand_6 = vector[vector[1, 0], vector[1, 0], vector[10, 0], vector[10, 0]];
        assert!(blackjack::calculate_hand_value_with_ace(hand_6) == 0, 0);
    }

    #[test]
    fun test_calculate_hand_value() {
        let hand_1 = vector[vector[1, 0], vector[2, 0]];
        assert!(blackjack::calculate_hand_value(hand_1) == blackjack::calculate_hand_value_with_ace(hand_1), 0);

        let hand_2 = vector[vector[1, 0], vector[1, 0]];
        assert!(blackjack::calculate_hand_value(hand_2) == blackjack::calculate_hand_value_with_ace(hand_2), 0);

        let hand_3 = vector[vector[1, 0], vector[1, 0], vector[1, 0]];
        assert!(blackjack::calculate_hand_value(hand_3) == blackjack::calculate_hand_value_with_ace(hand_3), 0);

        let hand_4 = vector[vector[1, 0], vector[1, 0], vector[10, 0]];
        assert!(blackjack::calculate_hand_value(hand_4) == blackjack::calculate_hand_value_with_ace(hand_4), 0);

        let hand_5 = vector[vector[1, 0], vector[1, 0], vector[10, 0], vector[10, 0]];
        assert!(blackjack::calculate_hand_value(hand_5) == blackjack::calculate_hand_value_with_ace(hand_5), 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_start_game(framework: &signer, aptosino: &signer, player: &signer) {
        setup_blackjack(framework, aptosino, player);
        let blackjack_hand_obj = blackjack::test_start_game(
            player, 
            BET_AMOUNT,
            vector[vector[1, 0], vector[2, 0]],
            vector[vector[3, 0]],
        );
        assert!(vector::length(&blackjack::get_player_cards(blackjack_hand_obj)) == 2, 0);
        assert!(vector::length(&blackjack::get_dealer_cards(blackjack_hand_obj)) == 1, 0);
        assert!(blackjack::get_bet_amount(signer::address_of(player)) == BET_AMOUNT, 0);
        assert!(blackjack::get_player_address(blackjack_hand_obj) == signer::address_of(player), 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_hit(framework: &signer, aptosino: &signer, player: &signer) {
        setup_blackjack(framework, aptosino, player);
        let blackjack_hand_obj = blackjack::test_start_game(
            player, 
            BET_AMOUNT,
            vector[vector[6, 0], vector[2, 0]],
            vector[vector[3, 0]],
        );
        blackjack::test_hit(
            blackjack_hand_obj,
            vector[7, 0],
        );
        assert!(vector::length(&blackjack::get_player_cards(blackjack_hand_obj)) == 3, 0);
        assert!(blackjack::calculate_hand_value(blackjack::get_player_cards(blackjack_hand_obj)) == 15, 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_deal_to_house(framework: &signer, aptosino: &signer, player: &signer) {
        setup_blackjack(framework, aptosino, player);
        let blackjack_hand_obj = blackjack::test_start_game(
            player, 
            BET_AMOUNT,
            vector[vector[6, 0], vector[2, 0]],
            vector[vector[3, 0]],
        );
        blackjack::test_deal_to_house(blackjack_hand_obj, vector[7, 0]);
        assert!(vector::length(&blackjack::get_dealer_cards(blackjack_hand_obj)) == 2, 0);
        assert!(blackjack::calculate_hand_value(blackjack::get_dealer_cards(blackjack_hand_obj)) == 10, 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_player_bust(framework: &signer, aptosino: &signer, player: &signer) {
        setup_blackjack(framework, aptosino, player);
        let player_address = signer::address_of(player);

        let player_balance_before = coin::balance<AptosCoin>(player_address);
        let house_balance_before = coin::balance<AptosCoin>(house::get_house_address());

        let blackjack_hand_obj = blackjack::test_start_game(
            player, 
            BET_AMOUNT,
            vector[vector[10, 0], vector[10, 0]],
            vector[vector[7, 0]],
        );

        blackjack::test_hit(
            blackjack_hand_obj,
            vector[10, 0],
        );

        assert!(coin::balance<AptosCoin>(player_address) == player_balance_before - BET_AMOUNT, 0);
        assert!(house::get_house_balance() == house_balance_before + BET_AMOUNT, 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_resolve_game_dealer_bust(framework: &signer, aptosino: &signer, player: &signer) {
        setup_blackjack(framework, aptosino, player);
        let player_address = signer::address_of(player);

        let player_balance_before = coin::balance<AptosCoin>(player_address);
        let house_balance_before = coin::balance<AptosCoin>(house::get_house_address());
        let fee = house::get_fee_amount(BET_AMOUNT);

        let blackjack_hand_obj = blackjack::test_start_game(
            player, 
            BET_AMOUNT,
            vector[vector[10, 0], vector[10, 0]],
            vector[vector[10, 0], vector[6, 0], vector[10, 0]]
        );
        blackjack::test_resolve_game(blackjack_hand_obj);

        assert!(coin::balance<AptosCoin>(player_address) == player_balance_before + BET_AMOUNT - fee, 0);
        assert!(house::get_house_balance() == house_balance_before - BET_AMOUNT + fee, 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_resolve_game_player_win_blackjack(framework: &signer, aptosino: &signer, player: &signer) {
        setup_blackjack(framework, aptosino, player);
        let player_address = signer::address_of(player);

        let player_balance_before = coin::balance<AptosCoin>(player_address);
        let house_balance_before = coin::balance<AptosCoin>(house::get_house_address());
        let fee = house::get_fee_amount(BET_AMOUNT);

        blackjack::test_start_game(
            player, 
            BET_AMOUNT,
            vector[vector[1, 0], vector[10, 0]],
            vector[vector[3, 0]],
        );

        assert!(coin::balance<AptosCoin>(player_address) == player_balance_before + BET_AMOUNT * 3 / 2 - fee, 0);
        assert!(house::get_house_balance() == house_balance_before - BET_AMOUNT * 3 / 2 + fee, 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_resolve_game_player_and_house_blackjack(framework: &signer, aptosino: &signer, player: &signer) {
        setup_blackjack(framework, aptosino, player);
        let player_address = signer::address_of(player);

        let player_balance_before = coin::balance<AptosCoin>(player_address);
        let house_balance_before = coin::balance<AptosCoin>(house::get_house_address());
        let fee = house::get_fee_amount(BET_AMOUNT);

        blackjack::test_start_game(
            player, 
            BET_AMOUNT,
            vector[vector[1, 0], vector[10, 0]],
            vector[vector[1, 0], vector[10, 0]]
        );

        assert!(coin::balance<AptosCoin>(player_address) == player_balance_before - fee, 0);
        assert!(house::get_house_balance() == house_balance_before + fee, 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_resolve_game_house_blackjack(framework: &signer, aptosino: &signer, player: &signer) {
        setup_blackjack(framework, aptosino, player);
        let player_address = signer::address_of(player);

        let player_balance_before = coin::balance<AptosCoin>(player_address);
        let house_balance_before = coin::balance<AptosCoin>(house::get_house_address());

        let blackjack_hand_obj = blackjack::test_start_game(
            player, 
            BET_AMOUNT,
            vector[vector[9, 0], vector[10, 0]],
            vector[vector[1, 0], vector[10, 0]]
        );

        blackjack::test_hit(blackjack_hand_obj, vector[2, 0]);

        assert!(coin::balance<AptosCoin>(player_address) == player_balance_before - BET_AMOUNT, 0);
        assert!(house::get_house_balance() == house_balance_before + BET_AMOUNT, 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_resolve_game_push(framework: &signer, aptosino: &signer, player: &signer) {
        setup_blackjack(framework, aptosino, player);
        let player_address = signer::address_of(player);

        let player_balance_before = coin::balance<AptosCoin>(player_address);
        let house_balance_before = coin::balance<AptosCoin>(house::get_house_address());
        let fee = house::get_fee_amount(BET_AMOUNT);

        let blackjack_hand_obj = blackjack::test_start_game(
            player, 
            BET_AMOUNT,
            vector[vector[10, 0], vector[10, 0]],
            vector[vector[10, 0]],
        );

        blackjack::test_deal_to_house(blackjack_hand_obj, vector[10, 0]);
        blackjack::test_resolve_game(blackjack_hand_obj);

        assert!(coin::balance<AptosCoin>(player_address) == player_balance_before - fee, 0);
        assert!(house::get_house_balance() == house_balance_before + fee, 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_resolve_game_player_win_non_blackjack(framework: &signer, aptosino: &signer, player: &signer) {
        setup_blackjack(framework, aptosino, player);
        let player_address = signer::address_of(player);

        let player_balance_before = coin::balance<AptosCoin>(player_address);
        let house_balance_before = coin::balance<AptosCoin>(house::get_house_address());
        let fee = house::get_fee_amount(BET_AMOUNT);

        let blackjack_hand_obj = blackjack::test_start_game(
            player, 
            BET_AMOUNT,
            vector[vector[9, 0], vector[9, 0]],
            vector[vector[10, 0]],
        );

        blackjack::test_deal_to_house(blackjack_hand_obj, vector[7, 0], );
        blackjack::test_resolve_game(blackjack_hand_obj);

        assert!(coin::balance<AptosCoin>(player_address) == player_balance_before + BET_AMOUNT - fee, 0);
        assert!(house::get_house_balance() == house_balance_before - BET_AMOUNT + fee, 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_resolve_game_player_lose(framework: &signer, aptosino: &signer, player: &signer) {
        setup_blackjack(framework, aptosino, player);
        let player_address = signer::address_of(player);

        let player_balance_before = coin::balance<AptosCoin>(player_address);
        let house_balance_before = coin::balance<AptosCoin>(house::get_house_address());

        let blackjack_hand_obj = blackjack::test_start_game(
            player, 
            BET_AMOUNT,
            vector[vector[10, 0], vector[9, 0]],
            vector[vector[10, 0]],
        );

        blackjack::test_deal_to_house(blackjack_hand_obj, vector[10, 0], );
        blackjack::test_resolve_game(blackjack_hand_obj, );

        assert!(coin::balance<AptosCoin>(player_address) == player_balance_before - BET_AMOUNT, 0);
        assert!(house::get_house_balance() == house_balance_before + BET_AMOUNT, 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_start_game_entry(framework: &signer, aptosino: &signer, player: &signer) {
        setup_blackjack(framework, aptosino, player);
        let player_address = signer::address_of(player);

        let player_balance_before = coin::balance<AptosCoin>(player_address);

        blackjack::start_game(player, BET_AMOUNT);

        assert!(coin::balance<AptosCoin>(player_address) == player_balance_before - BET_AMOUNT, 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_hit_entry(framework: &signer, aptosino: &signer, player: &signer) {
        setup_blackjack(framework, aptosino, player);

        let blackjack_hand_obj = blackjack::test_start_game(
            player, 
            BET_AMOUNT,
            vector[vector[6, 0], vector[2, 0]],
            vector[vector[3, 0]],
        );
        blackjack::test_hit_entry(player);

        assert!(vector::length(&blackjack::get_player_cards(blackjack_hand_obj)) == 3, 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_stand_entry(framework: &signer, aptosino: &signer, player: &signer) {
        setup_blackjack(framework, aptosino, player);
        let player_address = signer::address_of(player);

        let player_balance_before = coin::balance<AptosCoin>(player_address);
        let house_balance_before = house::get_house_balance();
        let fee = house::get_fee_amount(BET_AMOUNT);

        let blackjack_hand_obj = blackjack::test_start_game(
            player, 
            BET_AMOUNT,
            vector[vector[9, 0], vector[9, 0]],
            vector[vector[7, 0]],
        );
        blackjack::test_deal_to_house(blackjack_hand_obj, vector[10, 0]);
        blackjack::test_stand_entry(player);

        assert!(coin::balance<AptosCoin>(player_address) == player_balance_before + BET_AMOUNT - fee, 0);
        assert!(house::get_house_balance() == house_balance_before - BET_AMOUNT + fee, 0);
    }
}
