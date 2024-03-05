# Aptosino

![Aptosino](https://github.com/jasonhedman/aptosino/blob/main/diagram.png?raw=true)

Welcome to Aptosino, a decentralized platform for provably-fair gaming built on the Aptos blockchain. By leveraging Aptos' novel `randomness` module, we offer a transparent and secure casino experience where players can trust the integrity of every game outcome. Players can enjoy a wide range of classic casino games, knowing that the odds are truly in their favor.

## Architecture

Our casino is composed of several interconnected modules, each serving a specific purpose:

- `house.move`: Oversees casino operations and financial management
- `blackjack.move`: A classic card game where players aim to beat the dealer by getting a hand value closest to 21 without going over
- `roulette.move`: Place bets on where the ball will land on the spinning wheel, with various betting options available.
- `slots.move`: Spin the reels and match symbols to win prizes in this iconic casino game.
- `dice.move`: Roll the dice and bet on the outcome, with different betting possibilities.
- `poker.move`: Bet on the result of a 5-card draw

These modules interact seamlessly, leveraging the composability of the MoveVM and the randomness module for tamper-proof game outcomes.

## Randomness

Aptosino utilizes the [Aptos randomness module](https://github.com/aptos-foundation/AIPs/blob/main/aips/aip-41.md) to ensure fair and unbiased game outcomes
