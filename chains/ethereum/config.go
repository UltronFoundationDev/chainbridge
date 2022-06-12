// Copyright 2020 ChainSafe Systems
// SPDX-License-Identifier: LGPL-3.0-only

package ethereum

import (
	"errors"
	"fmt"
	"math/big"
	"unsafe"

	"github.com/UltronFoundationDev/chainbridge-utils/core"
	"github.com/UltronFoundationDev/chainbridge-utils/msg"
	"github.com/UltronFoundationDev/chainbridge/connections/ethereum/egs"
	utils "github.com/UltronFoundationDev/chainbridge/shared/ethereum"
	"github.com/ethereum/go-ethereum/common"
)

const DefaultGasLimit = 6721975
const DefaultGasPrice = 20000000000
const DefaultMinGasPrice = 0
const DefaultBlockConfirmations = 10
const DefaultBlockSuccessRetryInterval = 400
const DefaultGasMultiplier = 1

// Chain specific options
var (
	BridgeOpt                    = "bridge"
	Erc20HandlerOpt              = "erc20Handler"
	Erc721HandlerOpt             = "erc721Handler"
	GenericHandlerOpt            = "genericHandler"
	MaxGasPriceOpt               = "maxGasPrice"
	MinGasPriceOpt               = "minGasPrice"
	GasLimitOpt                  = "gasLimit"
	GasMultiplier                = "gasMultiplier"
	HttpOpt                      = "http"
	StartBlockOpt                = "startBlock"
	BlockConfirmationsOpt        = "blockConfirmations"
	BlockSuccessRetryIntervalOpt = "blockSuccessRetryInterval"
	EGSApiKey                    = "egsApiKey"
	EGSSpeed                     = "egsSpeed"
)

// Config encapsulates all necessary parameters in ethereum compatible forms
type Config struct {
	name                      string      // Human-readable chain name
	id                        msg.ChainId // ChainID
	endpoint                  string      // url for rpc endpoint
	from                      string      // address of key to use
	keystorePath              string      // Location of keyfiles
	blockstorePath            string
	freshStart                bool // Disables loading from blockstore at start
	bridgeContract            common.Address
	erc20HandlerContract      common.Address
	erc721HandlerContract     common.Address
	genericHandlerContract    common.Address
	gasLimit                  *big.Int
	maxGasPrice               *big.Int
	minGasPrice               *big.Int
	gasMultiplier             *big.Float
	http                      bool // Config for type of connection
	startBlock                *big.Int
	blockConfirmations        *big.Int
	blockSuccessRetryInterval *big.Int
	decimals                  map[msg.ChainId]map[string][2]int8
	egsApiKey                 string // API key for ethgasstation to query gas prices
	egsSpeed                  string // The speed which a transaction should be processed: average, fast, fastest. Default: fast
}

func b2arr32(b []byte) [32]byte {
	return *(*[32]byte)(unsafe.Pointer(&b))
}

// parseChainConfig uses a core.ChainConfig to construct a corresponding Config
func parseChainConfig(chainCfg *core.ChainConfig) (*Config, error) {

	config := &Config{
		name:                      chainCfg.Name,
		id:                        chainCfg.Id,
		endpoint:                  chainCfg.Endpoint,
		from:                      chainCfg.From,
		keystorePath:              chainCfg.KeystorePath,
		blockstorePath:            chainCfg.BlockstorePath,
		freshStart:                chainCfg.FreshStart,
		bridgeContract:            utils.ZeroAddress,
		erc20HandlerContract:      utils.ZeroAddress,
		erc721HandlerContract:     utils.ZeroAddress,
		genericHandlerContract:    utils.ZeroAddress,
		gasLimit:                  big.NewInt(DefaultGasLimit),
		maxGasPrice:               big.NewInt(DefaultGasPrice),
		minGasPrice:               big.NewInt(DefaultMinGasPrice),
		gasMultiplier:             big.NewFloat(DefaultGasMultiplier),
		http:                      false,
		startBlock:                big.NewInt(0),
		blockConfirmations:        big.NewInt(0),
		blockSuccessRetryInterval: big.NewInt(0),
		decimals:                  chainCfg.Decimals,
		egsApiKey:                 "",
		egsSpeed:                  "",
	}

	if contract, ok := chainCfg.Opts[BridgeOpt]; ok && contract != "" {
		config.bridgeContract = common.HexToAddress(contract)
		delete(chainCfg.Opts, BridgeOpt)
	} else {
		return nil, fmt.Errorf("must provide opts.bridge field for ethereum config")
	}

	if contract, ok := chainCfg.Opts[Erc20HandlerOpt]; ok {
		config.erc20HandlerContract = common.HexToAddress(contract)
		delete(chainCfg.Opts, Erc20HandlerOpt)
	}

	if contract, ok := chainCfg.Opts[Erc721HandlerOpt]; ok {
		config.erc721HandlerContract = common.HexToAddress(contract)
		delete(chainCfg.Opts, Erc721HandlerOpt)
	}

	if contract, ok := chainCfg.Opts[GenericHandlerOpt]; ok {
		config.genericHandlerContract = common.HexToAddress(contract)
		delete(chainCfg.Opts, GenericHandlerOpt)
	}

	if gasPrice, ok := chainCfg.Opts[MaxGasPriceOpt]; ok {
		price, parseErr := utils.ParseUint256OrHex(&gasPrice)
		if parseErr != nil {
			return nil, fmt.Errorf("unable to parse max gas price, %w", parseErr)
		}

		config.maxGasPrice = price
		delete(chainCfg.Opts, MaxGasPriceOpt)
	}

	if minGasPrice, ok := chainCfg.Opts[MinGasPriceOpt]; ok {
		price, parseErr := utils.ParseUint256OrHex(&minGasPrice)
		if parseErr != nil {
			return nil, fmt.Errorf("unable to parse min gas price, %w", parseErr)
		}

		config.minGasPrice = price
		delete(chainCfg.Opts, MinGasPriceOpt)
	}

	if gasLimit, ok := chainCfg.Opts[GasLimitOpt]; ok {
		limit, parseErr := utils.ParseUint256OrHex(&gasLimit)
		if parseErr != nil {
			return nil, fmt.Errorf("unable to parse gas limit, %w", parseErr)
		}

		config.gasLimit = limit
		delete(chainCfg.Opts, GasLimitOpt)
	}

	if gasMultiplier, ok := chainCfg.Opts[GasMultiplier]; ok {
		multilier := big.NewFloat(1)
		_, pass := multilier.SetString(gasMultiplier)
		if pass {
			config.gasMultiplier = multilier
			delete(chainCfg.Opts, GasMultiplier)
		} else {
			return nil, errors.New("unable to parse gasMultiplier to float")
		}
	}

	if HTTP, ok := chainCfg.Opts[HttpOpt]; ok && HTTP == "true" {
		config.http = true
		delete(chainCfg.Opts, HttpOpt)
	} else if HTTP, ok := chainCfg.Opts[HttpOpt]; ok && HTTP == "false" {
		config.http = false
		delete(chainCfg.Opts, HttpOpt)
	}

	if startBlock, ok := chainCfg.Opts[StartBlockOpt]; ok && startBlock != "" {
		block := big.NewInt(0)
		_, pass := block.SetString(startBlock, 10)
		if pass {
			config.startBlock = block
			delete(chainCfg.Opts, StartBlockOpt)
		} else {
			return nil, fmt.Errorf("unable to parse %s", StartBlockOpt)
		}
	}

	if blockConfirmations, ok := chainCfg.Opts[BlockConfirmationsOpt]; ok && blockConfirmations != "" {
		val := big.NewInt(DefaultBlockConfirmations)
		_, pass := val.SetString(blockConfirmations, 10)
		if pass {
			config.blockConfirmations = val
			delete(chainCfg.Opts, BlockConfirmationsOpt)
		} else {
			return nil, fmt.Errorf("unable to parse %s", BlockConfirmationsOpt)
		}
	} else {
		config.blockConfirmations = big.NewInt(DefaultBlockConfirmations)
		delete(chainCfg.Opts, BlockConfirmationsOpt)
	}

	if blockSuccessRetryInterval, ok := chainCfg.Opts[BlockSuccessRetryIntervalOpt]; ok && blockSuccessRetryInterval != "" {
		val := big.NewInt(DefaultBlockSuccessRetryInterval)
		_, pass := val.SetString(blockSuccessRetryInterval, 10)
		if pass {
			config.blockSuccessRetryInterval = val
			delete(chainCfg.Opts, BlockSuccessRetryIntervalOpt)
		} else {
			return nil, fmt.Errorf("unable to parse %s", BlockSuccessRetryIntervalOpt)
		}
	} else {
		config.blockSuccessRetryInterval = big.NewInt(DefaultBlockSuccessRetryInterval)
		delete(chainCfg.Opts, BlockSuccessRetryIntervalOpt)
	}

	if gsnApiKey, ok := chainCfg.Opts[EGSApiKey]; ok && gsnApiKey != "" {
		config.egsApiKey = gsnApiKey
		delete(chainCfg.Opts, EGSApiKey)
	}

	if speed, ok := chainCfg.Opts[EGSSpeed]; ok && speed == egs.Average || speed == egs.Fast || speed == egs.Fastest {
		config.egsSpeed = speed
		delete(chainCfg.Opts, EGSSpeed)
	} else {
		// Default to "average"
		config.egsSpeed = egs.Average
		delete(chainCfg.Opts, EGSSpeed)
	}

	if len(chainCfg.Opts) != 0 {
		return nil, fmt.Errorf("unknown Opts Encountered: %#v", chainCfg.Opts)
	}

	return config, nil
}
