// Copyright 2020 ChainSafe Systems
// SPDX-License-Identifier: LGPL-3.0-only

package ethereum

import (
	"errors"
	"github.com/ChainSafe/chainbridge-utils/msg"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"math/big"
)

func (l *listener) handleErc20DepositedEvent(destId msg.ChainId, nonce msg.Nonce, resourceID msg.ResourceId, callData []byte) (msg.Message, error) {
	l.log.Info("Handling fungible deposit event", "dest", destId, "nonce", nonce)

	if len(callData) < 84 {
		err := errors.New("invalid calldata length: less than 84 bytes")
		return msg.Message{}, err
	}

	// 32-64 is recipient address length
	recipientAddressLength := big.NewInt(0).SetBytes(callData[32:64])

	// 64 - (64 + recipient address length) is recipient address
	recipientAddress := callData[64:(64 + recipientAddressLength.Int64())]

	// amount: first 32 bytes of calldata
	amount := big.NewInt(0).SetBytes(callData[:32])

	return msg.NewFungibleTransfer(
		l.cfg.id,
		destId,
		nonce,
		amount,
		resourceID,
		recipientAddress,
	), nil
}

func (l *listener) handleErc721DepositedEvent(destId msg.ChainId, nonce msg.Nonce) (msg.Message, error) {
	l.log.Info("Handling nonfungible deposit event")

	record, err := l.erc721HandlerContract.GetDepositRecord(&bind.CallOpts{From: l.conn.Keypair().CommonAddress()}, uint64(nonce), uint8(destId))
	if err != nil {
		l.log.Error("Error Unpacking ERC721 Deposit Record", "err", err)
		return msg.Message{}, err
	}

	return msg.NewNonFungibleTransfer(
		l.cfg.id,
		destId,
		nonce,
		record.ResourceID,
		record.TokenID,
		record.DestinationRecipientAddress,
		record.MetaData,
	), nil
}

func (l *listener) handleGenericDepositedEvent(destId msg.ChainId, nonce msg.Nonce) (msg.Message, error) {
	l.log.Info("Handling generic deposit event")

	record, err := l.genericHandlerContract.GetDepositRecord(&bind.CallOpts{From: l.conn.Keypair().CommonAddress()}, uint64(nonce), uint8(destId))
	if err != nil {
		l.log.Error("Error Unpacking Generic Deposit Record", "err", err)
		return msg.Message{}, nil
	}

	return msg.NewGenericTransfer(
		l.cfg.id,
		destId,
		nonce,
		record.ResourceID,
		record.MetaData[:],
	), nil
}
