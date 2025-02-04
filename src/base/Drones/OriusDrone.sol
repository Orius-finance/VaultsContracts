// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {DroneLib} from "src/base/Drones/DroneLib.sol";

//                                            .
//                                         ......
//                                         ..........
//                                         ..:::.......
//                                         ..::........
//                                         ....::::.......
//                                         ......::..:....
//                                         ........:..:...
//                   ............          .......:.:........
//                    ..:::.........       ..........:..::...
//                    ....::::..::.....    ..........:...::..
//                      ....-:::...::....  ...............:-...
//                       .....--::::.::................:...:...
//                           ...:-::::::::..............:..:::.
//                            .....--:::::-:.............:::::....
//                               ....:==-:::--............::..-...
//                                 .....:*+-:::::..........::.:-..
//                                   ......:+*=---:.......:::::::......
//                              ........::::--+#*==:....:-------::........
//                           .....-=---=+-=+--===##==:..-+++++=====---:....
//                         ....=*##*====-+*=++=-===+#+=-=*+**+*******+==:......
//                    .....==:=####*=----*+==+=====::=#*++*******##*****=-:.......
//                 ......:##+-++=+++=---+####*+==--:--=+#%#*###**********==++=-.....
//                 ....-:+%*=---===++==+*%%%###++=-----+*#@%###@%%###****#*#%%**+=:..
//                 ..:*=-===----+*###**++%###%%#*+=+====+++**#@@%%%##**#%%#%@%###*-....
//                 ..+#=--++*+++*#%%%##***#%%%%%%#*+++==+***+++=+%%###%%%%%%%%@%##=.::.
//                ..-=#+==+#%%#***#++##%######%##%@%#*++##*+**+*##%%#%##%##+##@@%*+:=+:.
//               ..=+-*%%#*+#%%*+=%@#+*%@%%%%%%###%#*===*********##%%%*#*#@@%@%%*=-==::..
//               ..*%#++####***+#@@%===-=+#%@%*+++##+=-==+*******#%@%*=##%@@@@%%**+=-+:..
//               ..=###*++**+=+%@@@#--::.....::-*#=++=---==++++*#%%#+=-**@@@@@%**#-....
//              ...-**++++===+@%%%%=...........+#*+##=::::::-=+%*---::-=+#@@@%#+##-....
//              ....::::::---@@@%#*:...    ...-#@#:........:=%@#:.....::=+*###**##:.
//                 ..........=+%@%=..      ...*%%*.........:#@%-....=-:::-=+***#+-...
//                       ...#@%%%#:..      ..:%@@=..     ...+%%... ...==---+*##*=...
//                      ...#@@@@@%:.       ..:#@%:..     ..=*#-... ..........-#**...
//                      ..*@@@@@%-...      ..:*#+....   ..=*@%..          ....=+..
//                     ..:%@%%%#:...       ..-@@%:...   ..+@@+.              ....
//                   .....-*%%*...         ..=@@%-...  ...=%#:.
//                   ....:*#:.....         ..-@%%-..   ..:%=...
//                 ..:+++-.......          ...+*#:.. ....**:.
//                 ..-:......              ....==.......=*:..
//                 ....                    ...-#:. ....-+:...
//                 ....                    ..:=:.. ..:*=....
//                                         ....... .:=-...
//                                ...              .......
//
//
contract OriusDrone is ERC721Holder, ERC1155Holder {
    using Address for address;

    //============================== MODIFIERS ===============================

    modifier onlyOriusVault() {
        if (msg.sender != oriusVault) revert OriusDrone__OnlyOriusVault();
        _;
    }

    //============================== ERRORS ===============================

    error OriusDrone__OnlyOriusVault();
    error OriusDrone__ReceiveFailed();

    //============================== CONSTRUCTOR ===============================

    /**
     * @notice The address of the OriusVault that can control this drone.
     */
    address internal immutable oriusVault;

    /**
     * @notice The amount of gas needed to forward native to the OriusVault.
     * @dev This value was determined from guess and check. Realisitically, the value should be closer to 10k, but
     *      21k is used for extra safety.
     */
    uint256 internal immutable safeGasToForwardNative;

    constructor(address _oriusVault, uint256 _safeGasToForwardNative) {
        oriusVault = _oriusVault;
        safeGasToForwardNative = _safeGasToForwardNative < 21_000 ? 21_000 : _safeGasToForwardNative;
    }

    //============================== WITHDRAW ===============================

    /**
     * @notice Withdraws all native from the drone.
     */
    function withdrawNativeFromDrone() external onlyOriusVault {
        (bool success,) = oriusVault.call{value: address(this).balance}("");
        if (!success) revert OriusDrone__ReceiveFailed();
    }

    //============================== FALLBACK ===============================

    /**
     * @notice This contract in its current state can only be interacted with by the OriusVault.
     * @notice The real target is extracted from the call data using `extractTargetFromCalldata()`.
     * @notice The drone then forwards
     */
    fallback() external payable onlyOriusVault {
        // Extract real target from end of calldata
        address target = DroneLib.extractTargetFromCalldata();

        // Forward call to real target.
        target.functionCallWithValue(msg.data, msg.value);
    }

    //============================== RECEIVE ===============================

    receive() external payable {
        // If gas left is less than safe gas needed to forward native, return.
        if (gasleft() < safeGasToForwardNative) return;

        (bool success,) = oriusVault.call{value: msg.value}("");
        if (!success) revert OriusDrone__ReceiveFailed();
    }
}
