//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract RPS {
    constructor() payable {}

    enum Hand {
        rock,
        paper,
        scissors,
        nil
    }
    enum PlayerStatus {
        STATUS_WIN,
        STATUS_LOSE,
        STATUS_DRAW,
        STATUS_PENDING
    }
    enum GameStatus {
        STATUS_NOT_STARTED,
        STATUS_STARTED,
        STATUS_COMPLETE,
        STATUS_ERROR
    }

    struct Player {
        address payable addr;
        uint256 playerBetAmount;
        bytes32 hand;
        PlayerStatus playerStatus;
    }
    struct Game {
        Player originator;
        Player taker;
        uint256 betAmount;
        GameStatus gameStatus;
    }
    mapping(uint256 => Game) rooms;
    uint256 roomLen = 0;

    modifier isValidHand(bytes32 _EncryptionHand) {
        require(
            (_EncryptionHand == Encryption(0, msg.sender)) ||
                (_EncryptionHand == Encryption(1, msg.sender)) ||
                (_EncryptionHand == Encryption(2, msg.sender))
        );
        _;
    }
    modifier isPlayer(uint256 roomNum, address sender) {
        require(
            sender == rooms[roomNum].originator.addr ||
                sender == rooms[roomNum].taker.addr
        );
        _;
    }

    function Encryption(uint256 _hand, address _owner)
        public
        pure
        returns (bytes32)
    {
        require(_hand == 0 || _hand == 1 || _hand == 2);
        return keccak256(abi.encodePacked(_hand, _owner));
    }

    function createRoom(bytes32 _hand)
        public
        payable
        isValidHand(_hand)
        returns (uint256 roomNum)
    {
        rooms[roomLen] = Game({
            betAmount: msg.value,
            gameStatus: GameStatus.STATUS_NOT_STARTED,
            originator: Player({
                hand: _hand,
                addr: payable(msg.sender),
                playerStatus: PlayerStatus.STATUS_PENDING,
                playerBetAmount: msg.value
            }),
            taker: Player({
                hand: 0,
                addr: payable(msg.sender),
                playerStatus: PlayerStatus.STATUS_PENDING,
                playerBetAmount: 0
            })
        });
        roomNum = roomLen;
        roomLen = roomLen + 1;
    }

    function joinRoom(uint256 roomNum, bytes32 _hand)
        public
        payable
        isValidHand(_hand)
    {
        rooms[roomNum].taker = Player({
            hand: _hand,
            addr: payable(msg.sender),
            playerStatus: PlayerStatus.STATUS_PENDING,
            playerBetAmount: msg.value
        });
        rooms[roomNum].betAmount = rooms[roomNum].betAmount + msg.value;
        compareHands(roomNum);
    }

    function payout(uint256 roomNum)
        public
        payable
        isPlayer(roomNum, msg.sender)
    {
        if (
            rooms[roomNum].originator.playerStatus ==
            PlayerStatus.STATUS_DRAW &&
            rooms[roomNum].taker.playerStatus == PlayerStatus.STATUS_DRAW
        ) {
            rooms[roomNum].originator.addr.transfer(
                rooms[roomNum].originator.playerBetAmount
            );
            rooms[roomNum].taker.addr.transfer(
                rooms[roomNum].taker.playerBetAmount
            );
        } else {
            if (
                rooms[roomNum].originator.playerStatus ==
                PlayerStatus.STATUS_WIN
            ) {
                rooms[roomNum].originator.addr.transfer(
                    rooms[roomNum].betAmount
                );
            } else if (
                rooms[roomNum].taker.playerStatus == PlayerStatus.STATUS_WIN
            ) {
                rooms[roomNum].taker.addr.transfer(rooms[roomNum].betAmount);
            } else {
                rooms[roomNum].originator.addr.transfer(
                    rooms[roomNum].originator.playerBetAmount
                );
                rooms[roomNum].taker.addr.transfer(
                    rooms[roomNum].taker.playerBetAmount
                );
            }
        }
        rooms[roomNum].gameStatus = GameStatus.STATUS_COMPLETE;
    }

    function decodeHand(bytes32 _hand, address playerAddress)
        private
        pure
        returns (uint8 playerHand)
    {
        if (_hand == Encryption(0, playerAddress)) {
            playerHand = 0;
        } else if (_hand == Encryption(1, playerAddress)) {
            playerHand = 1;
        } else if (_hand == Encryption(2, playerAddress)) {
            playerHand = 2;
        }
        return playerHand;
    }

    function compareHands(uint256 roomNum) private {
        uint8 originator = decodeHand(
            rooms[roomNum].originator.hand,
            rooms[roomNum].originator.addr
        );
        uint8 taker = decodeHand(
            rooms[roomNum].taker.hand,
            rooms[roomNum].taker.addr
        );

        rooms[roomNum].gameStatus = GameStatus.STATUS_STARTED;
        if (taker == originator) {
            rooms[roomNum].originator.playerStatus = PlayerStatus.STATUS_DRAW;
            rooms[roomNum].taker.playerStatus = PlayerStatus.STATUS_DRAW;
        } else if ((taker + 1) % 3 == originator) {
            rooms[roomNum].originator.playerStatus = PlayerStatus.STATUS_WIN;
            rooms[roomNum].taker.playerStatus = PlayerStatus.STATUS_LOSE;
        } else if ((originator + 1) % 3 == taker) {
            rooms[roomNum].originator.playerStatus = PlayerStatus.STATUS_LOSE;
            rooms[roomNum].taker.playerStatus = PlayerStatus.STATUS_WIN;
        } else {
            rooms[roomNum].gameStatus = GameStatus.STATUS_ERROR;
        }
    }
}
