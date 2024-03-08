# Aptosino Move Modules

This directory contains the source code for the Move modules that are used in the Aptosino project.

## ```house.move```

This file contains the implementation of the house resource account and associated ```House``` resource. It is responsible for managing the betting parameters, approving games, and handling payouts. It also contains functions for setting and getting various parameters such as the minimum bet, maximum bet, maximum multiplier, and fee in basis points. The house resource also has the ability to revoke games and to withdraw accrued fees.

### Features
- Initialize the house with betting parameters and initial coin deposit
- Approve and revoke games that can interact with the house
- Pay out bets to bettors
- Admin functions to withdraw accrued fees, deposit coins, and set various parameters like minimum and maximum bets, fee basis points, and maximum multipliers
- View functions to get house details like admin address, betting parameters, and accrued fees

### Usage

#### Initialization
To initialize the house, the init function must be called by the deployer of the module with the initial parameters and coins to deposit into the house resource account.

```move
public entry fun init(
    deployer: &signer,
    initial_coins: u64,
    min_bet: u64,
    max_bet: u64,
    max_multiplier: u64,
    fee_bps: u64
) acquires House
```

#### Betting Functions

The ```pay_out``` function is used to pay out a bet to the bettor. It is only accessible by approved games.

```move
public(friend) fun pay_out<GameType: drop>(
    bettor: address,
    bet: Coin<AptosCoin>,
    payout_numerator: u64,
    payout_denominator: u64,
    _witness: GameType
) acquires House
```

### Admin Functions

Admin functions include approving games, revoking game approvals, withdrawing fees, depositing coins, and setting various house parameters.

```move
public fun approve_game<GameType: drop>(signer: &signer, _witness: GameType) acquires House
public entry fun revoke_game<GameType: drop>(signer: &signer) acquires House, ApprovedGame
public entry fun withdraw_fees(signer: &signer) acquires House
public entry fun deposit(signer: &signer, amount: u64) acquires House
public entry fun set_admin(signer: &signer, admin: address) acquires House
public entry fun set_min_bet(signer: &signer, min_bet: u64) acquires House
public entry fun set_max_bet(signer: &signer, max_bet: u64) acquires House
public entry fun set_fee_bps(signer: &signer, fee_bps: u64) acquires House
public entry fun set_max_multiplier(signer: &signer, max_multiplier: u64) acquires House
```

### Getters

Information about the house - admin address, betting parameters, and accrued fees - is available through the view functions of the module

```move
public fun get_house_address(): address
public fun get_admin_address(): address acquires House
public fun get_min_bet(): u64 acquires House
public fun get_max_bet(): u64 acquires House
public fun get_max_multiplier(): u64 acquires House
public fun get_fee_bps(): u64 acquires House
public fun get_accrued_fees(): u64 acquires House
public fun get_house_balance(): u64
public fun get_fee_amount(bet_amount: u64): u64 acquires House
public fun is_game_approved<GameType: drop>(): bool
```

## ```game.move```

The ```aptosino::game``` module the functionality to create and resolve games that interface with ```house.move```. It ensures that games are approved and that bets are handled correctly.

### Features
- Creation of game structures with player bets
- Resolution of games with appropriate payouts
- Event emission upon game resolution
- Getter functions to retrieve player addresses and bet amounts
- Assertions to ensure game integrity and player eligibility

### Usage

#### Game Creation

To create a game, the ```create_game``` function is called with the player's signer, the bet amount, and a witness instance of the ```GameType``` struct.

```move
public fun create_game<GameType: drop>(
    player: &signer,
    bet_amount: u64,
    _witness: GameType
): Game
```

#### Game Resolution

The ```resolve_game``` function resolves a game by paying out the player based on the provided payout numerator and denominator, and emits a ```GameResolved``` event.

```move
public fun resolve_game<GameType: drop>(
    game: Game,
    payout_numerator: u64,
    payout_denominator: u64,
    witness: GameType
)
```

#### Getters

Getter functions are provided to retrieve the address of the player and the amount bet from a Game struct.

```move
public fun get_player_address(game: &Game): address
public fun get_bet_amount(game: &Game): u64
```

#### Assertions

The module includes several assertions to ensure that games are approved, bets are valid, and players have sufficient balance.

```move
fun assert_game_is_approved<GameType: drop>()
fun assert_bet_amount_is_greater_than_zero(amount: u64)
fun assert_player_has_enough_balance(player_address: address, amount: u64)
```


## ```state_based_game.move```

The ```aptosino::state_based_game module``` leverages ```aptos_framework::object```  to manage stateful games and ```aptos_std::smart_table``` to mapping player addresses to game objects.

### Features
- Initialization of state-based games for specific game types
- Creation and resolution of game objects tied to player addresses
- Mapping of player addresses to game objects using SmartTable
- Getter functions to check game initialization, player participation, and retrieve game-related information
- Assertions to ensure proper game state and player eligibility

### Usage

#### Game Initialization

To initialize a new state-based game, the init function is called with the creator's signer and a witness instance of the game type.

```move
public fun init<GameType: drop>(creator: &signer, _witness: GameType)
```

#### Game Creation and Resolution

The ```create_game``` function adds a game object for a given player and game type, storing it in the mapping for the GameType.

```move
public fun create_game<GameType: drop>(
    player: &signer,
    bet_amount: u64,
    _witness: GameType
): ConstructorRef acquires GameMapping
```

The ```resolve_game``` function removes a game address for a given player and game type, pays out the player, and deletes the associated game object.

```move
public fun resolve_game<GameType: drop>(
    player_address: address,
    payout_numerator: u64,
    payout_denominator: u64,
    witness: GameType
) acquires GameMapping
```

#### Getters

Getter functions provide the ability to check if a game is initialized, if a player is in a game, and to retrieve the address and bet amount of the player's game.

```move
public fun get_is_game_initialized<GameType: drop>(): bool
public fun get_is_player_in_game<GameType: drop>(player: address): bool acquires GameMapping
public fun get_player_game_address<GameType: drop>(player: address): address acquires GameMapping
public fun get_player_bet_amount<GameType: drop>(player: address): u64 acquires GameMapping
public fun get_game_object<GameType: drop, Game: key>(player_address: address): Object<Game> acquires GameMapping
```

#### Assertions

The module includes assertions to ensure that the caller is the game creator, the game is properly initialized, and the player's game state is correct.

```move
fun assert_caller_is_creator<GameType: drop>(creator: &signer)
fun assert_game_initialized<GameType: drop>()
fun assert_game_not_initialized<GameType: drop>()
fun assert_player_in_game<GameType: drop>(player: address) acquires GameMapping
fun assert_player_not_in_game<GameType: drop>(player: address) acquires GameMapping
```