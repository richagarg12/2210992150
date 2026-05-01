// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract EnergyTrading {
    mapping(address => uint256) public energyBalance;
    mapping(address => uint256) public energyExpiry;
    mapping(address => uint256) public energyLimit;
    mapping(address => uint256) public lastReductionTime; // Track last reduction time
    mapping(address => uint256) public creditBalance; // Track credits for each block

    address public admin;
    uint256 public transferFeePercent;
    uint256 public energyDepletionRate; // Energy points to reduce per second
    uint256 public sharedEnergyPool; // Pool for shared energy contributions

    event EnergyTransferred(address indexed from, address indexed to, uint256 amount);
    event BlockAdded(address indexed blockAddress, uint256 initialEnergy);
    event BlockRemoved(address indexed blockAddress);
    event EnergyReduced(address indexed blockAddress, uint256 reductionAmount);
    event EnergyWarning(address indexed blockAddress, uint256 remainingEnergy);
    event EnergyContributed(address indexed blockAddress, uint256 amount, uint256 creditsEarned);
    event EnergyDrawnFromPool(address indexed blockAddress, uint256 amount, uint256 creditsUsed);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    constructor(uint256 _transferFeePercent, uint256 _energyDepletionRate) {
        admin = msg.sender;
        transferFeePercent = _transferFeePercent;
        energyDepletionRate = _energyDepletionRate;
    }

    function addBlock(address _block, uint256 _initialEnergy, uint256 _expiryTime, uint256 _energyLimit) public onlyAdmin {
        require(energyBalance[_block] == 0, "Block already exists");
        energyBalance[_block] = _initialEnergy;
        energyExpiry[_block] = block.timestamp + _expiryTime;
        energyLimit[_block] = _energyLimit;
        lastReductionTime[_block] = block.timestamp; // Initialize last reduction time

        emit BlockAdded(_block, _initialEnergy);
    }

    function removeBlock(address _block) public onlyAdmin {
        require(energyBalance[_block] > 0, "Block does not exist");
        energyBalance[_block] = 0;
        energyExpiry[_block] = 0;
        energyLimit[_block] = 0;

        emit BlockRemoved(_block);
    }

    // Contribute energy to the shared pool and earn credits
    function contributeToPool(address _block, uint256 _amount) public {
        require(energyBalance[_block] >= _amount, "Insufficient energy to contribute");
        require(block.timestamp <= energyExpiry[_block], "Energy has expired");

        // Transfer energy to the shared pool
        energyBalance[_block] -= _amount;
        sharedEnergyPool += _amount;

        // Credits earned is proportional to energy contributed
        uint256 creditsEarned = _amount / 10; // Example: 1 credit per 10 energy units
        creditBalance[_block] += creditsEarned;

        emit EnergyContributed(_block, _amount, creditsEarned);
    }

    // Draw energy from the shared pool in exchange for credits
    function drawFromPool(address _block, uint256 _amount) public {
        require(sharedEnergyPool >= _amount, "Insufficient energy in pool");
        uint256 creditsRequired = _amount / 10; // Example: 1 credit per 10 energy units
        require(creditBalance[_block] >= creditsRequired, "Insufficient credits");

        // Deduct from pool and credit balance
        sharedEnergyPool -= _amount;
        energyBalance[_block] += _amount;
        creditBalance[_block] -= creditsRequired;

        emit EnergyDrawnFromPool(_block, _amount, creditsRequired);
    }

    function reduceEnergy(address _block) public {
        require(energyBalance[_block] > 0, "Block does not exist");

        uint256 reductionAmount = 1; // Example reduction per call
        uint256 newBalance = energyBalance[_block] - reductionAmount;
        require(newBalance >= energyLimit[_block], "Energy would drop below the limit");

        energyBalance[_block] = newBalance;

        emit EnergyReduced(_block, reductionAmount);

        if (newBalance < energyLimit[_block] + 10) {
            emit EnergyWarning(_block, newBalance);
        }
    }

    function transferEnergy(address _from, address _to, uint256 _amount) public {
        require(energyBalance[_from] >= _amount, "Insufficient energy in sender block");
        require(block.timestamp <= energyExpiry[_from], "Energy has expired in the sender block");

        uint256 transferFee = (_amount * transferFeePercent) / 100;
        uint256 energyToTransfer = _amount - transferFee;

        energyBalance[_from] -= _amount;
        energyBalance[_to] += energyToTransfer;

        emit EnergyTransferred(_from, _to, energyToTransfer);
    }

    function getBlockInfo(address _block) public view returns (uint256 energy, uint256 expiry, uint256 credits) {
        return (energyBalance[_block], energyExpiry[_block], creditBalance[_block]);
    }

    function setTransferFeePercent(uint256 _newFeePercent) public onlyAdmin {
        transferFeePercent = _newFeePercent;
    }
}