import {Authority} from "@solmate/auth/Auth.sol";

contract SimpleAuthority is Authority {
    address owner = msg.sender;

    mapping(address => bool) allowed;

    constructor() {
        allowed[0x21B18e8c6c8e4eB7f05Fa6A48373002AA389Feec] = true;
        allowed[0x4BEB1413d5B15B147458242Fc6E96bF8f6635F52] = true;
        allowed[0x5b73C5498c1E3b4dbA84de0F1833c4a029d90519] = true; // default forge account, helps with tests
    }

    function setAllowed(address user, bool permission) public {
        require(owner == msg.sender);
        allowed[user] = permission;
    }

    function canCall(
        address user,
        address target,
        bytes4 functionSig
    ) external view returns (bool) {
        return allowed[user];
    }
}
