module aptosino::oneshotmines {

    use std::signer;
    use std::vector;

    use aptos_framework::event;
    use aptos_framework::randomness;
    use aptosino::game;

    use aptosino::house;

    // constants

    const MAX_ROWS: u8 = 50;
    const MAX_COLS: u8 = 50;

    // error codes

    /// The mines board has invalid rows
    const EMinesMachineInvalidRows: u64 = 101;
    /// The mines board has invalid columns
    const EMinesMachineInvalidCols: u64 = 102;
    /// The mines board has invalid mines
    const EMinesMachineInvalidMines: u64 = 103;
    /// There are no more gems to reveal
    const EUnexpectedTotalNumberOfCells: u64 = 104;
    /// The board is empty
    const EBoardEmpty: u64 = 105;
    /// The bet amount is invalid
    const EInvalidBetAmount: u64 = 106;

    // game type

    struct OneShotMinesGame has drop {}

    // Events

    #[event]
    /// Event emitted when the player chooses a cell to reveal
    struct ChooseCellEvent has key {
        /// The address of the player
        player_address: address,
        /// The amount being wagered
        bet_amount: u64,
        /// Whether the player won or lost
        won: bool,
    }

    // admin functions

    /// Approves the dice game on the house module
    /// * admin: the signer of the admin account
    public entry fun approve_game(admin: &signer) {
        house::approve_game<OneShotMinesGame>(admin, OneShotMinesGame{});
    }

    // game functions

    /// Based on the given set of revealed coordinates
    /// * player: the signer of the player account
    /// * bet_amount_inputs: the amount to bet on each predicted outcome
    /// * predicted_outcomes: the numbers the player predicts for each corresponding bet
    public entry fun choose_cell(
        player: &signer,
        bet_amount_input: u64,
        num_rows: u8,
        num_cols: u8,
        num_revealed: u8,
        num_mines: u8,
    ) {
        assert_board_is_valid(num_rows, num_cols, num_revealed, num_mines);
        let num_cells_remaining = num_rows * num_cols - num_revealed;
        let result = randomness::u8_range(0, num_cells_remaining);
        choose_cell_impl(player, bet_amount_input, num_cells_remaining, num_mines, result);
    }

    /// Implementation of the choose_cell function, extracted to allow testing
    /// * player: the signer of the player account
    /// * bet_amounts: the amount to bet on each predicted outcome
    /// * predicted_outcomes: the numbers the player predicts for each corresponding bet
    /// * result: the result of the spin
    fun choose_cell_impl(
        player: &signer,
        bet_amount: u64,
        num_cells_remaining: u8,
        num_mines: u8,
        result: u8
    ) {
        assert_bet_is_valid(&bet_amount);

        let game = game::create_game(player, bet_amount, OneShotMinesGame {});

        let payout_numerator = 0;
        let payout_denominator = 0;

        if (result < num_mines) {
            payout_numerator = 0;
            payout_denominator = 1;
        } else {
            payout_numerator = (num_mines as u64);
            payout_denominator = (num_cells_remaining as u64);
        };

        game::resolve_game(
            game,
            payout_numerator,
            if(payout_denominator > 0) { payout_denominator } else { 1 },
            OneShotMinesGame {}
        );

        event::emit(ChooseCellEvent {
            player_address: signer::address_of(player),
            bet_amount,
            won: result >= num_mines,
        });
    }

    // getters

    #[view]
    /// Returns the payout for a given bet
    /// * bet_amount: the amount to bet
    /// * num_cells_remaining: the number of cells remaining to be revealed
    /// * num_mines: the number of mines on the board
    public fun get_payout(
        bet_amount: u64,
        num_cells_remaining: u8,
        num_mines: u8
    ) :u64 {
        bet_amount * (num_cells_remaining as u64) / (num_mines as u64)
    }
    // assert statements

    /// Asserts that the board is valid
    fun assert_board_is_valid(
        num_rows: u8,
        num_cols: u8,
        num_revealed: u8,
        num_mines: u8,
    ) {
        assert!(num_rows > 0 && num_rows < MAX_ROWS, EMinesMachineInvalidRows);
        assert!(num_cols > 0 && num_cols < MAX_COLS, EMinesMachineInvalidCols);
        let num_remaining = num_rows * num_cols - num_revealed;
        assert!(num_remaining > 0, EBoardEmpty);
        assert!(num_mines > 0 && num_mines < num_remaining, EMinesMachineInvalidMines);
        assert!(num_revealed + num_remaining == num_rows * num_cols, EUnexpectedTotalNumberOfCells);
    }

    /// Asserts that the bet is valid
    fun assert_bet_is_valid(
        bet_amount: &u64,
    ) {
        assert!(*bet_amount > 0, EInvalidBetAmount);
    }

    // test functions

    #[test_only]
    public fun test_choose_cell(
          player: &signer,
          bet_amount: u64,
          num_cells_remaining: u8,
          num_mines: u8,
          result: u8
    ) {
        choose_cell_impl(player, bet_amount, num_cells_remaining, num_mines, result);
    }
}
