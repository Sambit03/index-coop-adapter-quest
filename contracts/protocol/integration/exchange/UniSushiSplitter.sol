/*
    Copyright 2021 Set Labs Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

    SPDX-License-Identifier: Apache License, Version 2.0
*/

pragma solidity 0.6.10;
pragma experimental "ABIEncoderV2";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

import { IUniswapV2Factory } from "../../../interfaces/external/IUniswapV2Factory.sol";
import { IUniswapV2Router } from "../../../interfaces/external/IUniswapV2Router.sol";
import { PreciseUnitMath } from "../../../lib/PreciseUnitMath.sol";

contract UniSushiSplitter {

    using SafeMath for uint256;
    using PreciseUnitMath for uint256;

    IUniswapV2Router public immutable uniRouter;
    IUniswapV2Router public immutable sushiRouter;

    constructor(IUniswapV2Router _uniRouter, IUniswapV2Router _sushiRouter) public {
        uniRouter = _uniRouter;
        sushiRouter = _sushiRouter;
    }

    function swapExactTokensForTokens(
        uint _amountIn,
        uint _amountOutMin,
        address[] calldata _path,
        address _to,
        uint _deadline
    )
        external
        returns (uint256)
    {

        uint256 uniSplit = _getUniSplit(_amountIn, _path);

        uint256 uniTradeSize = uniSplit.preciseMul(_amountIn);
        uint256 sushiTradeSize = _amountIn.sub(uniTradeSize);

        uint256 uniAmountOutMin = uniSplit.preciseMul(_amountOutMin);
        uint256 sushiAmountOutMin = _amountOutMin.sub(uniAmountOutMin);

        uint256 uniOutput = uniRouter.swapExactTokensForTokens(uniTradeSize, uniAmountOutMin, _path, _to, _deadline)[_path.length.sub(1)];
        uint256 sushiOutput = sushiRouter.swapExactTokensForTokens(sushiTradeSize, sushiAmountOutMin, _path, _to, _deadline)[_path.length.sub(1)];

        return uniOutput.add(sushiOutput);
    }

    function _getUniSplit(uint256 _amountIn, address[] calldata _path) internal view returns (uint256) {
        ERC20 inputToken = ERC20(_path[0]);
        
        uint256 fairOutputUni = uniRouter.getAmountsOut(uint256(10) ** inputToken.decimals(), _path)[_path.length.sub(1)];
        uint256 fairOutputSushi = sushiRouter.getAmountsOut(uint256(10) ** inputToken.decimals(), _path)[_path.length.sub(1)];

        uint256 impactOutputUni = uniRouter.getAmountsOut(_amountIn, _path)[_path.length.sub(1)];
        uint256 impactOutputSushi = sushiRouter.getAmountsOut(_amountIn, _path)[_path.length.sub(1)];

        uint256 priceImpactUni = fairOutputUni.sub(impactOutputUni).preciseDiv(fairOutputUni);
        uint256 priceImpactSushi = fairOutputSushi.sub(impactOutputSushi).preciseDiv(fairOutputSushi);

        return priceImpactUni.div(priceImpactUni.add(priceImpactSushi));
    }
}