const depositABI = require("../../artifacts/contracts/depositvault.sol/DepositVault.json")
const hre = require("hardhat");
const tokenabi = require("./token_abi.json");

async function deposit(){

    const depositvault = "0x9F7c609C7d42fa510c4375b1DAd7dd5ED17F74F0"
    const taker = await hre.ethers.provider.getSigner(0); // deposit usdt  // 0x8d23Bd68E5c095B7A1999E090B2F9c20114CbBb4
    const USDT = "0xdfc6a3f2d7daff1626Ba6c32B79bEE1e1d6259F0"

    const contractABI = tokenabi.abi; // token abi for approvals 
    const deposit_amount ="100000000000000000000"

    const TOKENCONTRACT = new hre.ethers.Contract(USDT, contractABI, taker);
    // Wait for approval transaction to finish
    const approvalTx = await TOKENCONTRACT.approve(depositvault, deposit_amount);
    await approvalTx.wait();  // Wait for the transaction to be mined


    console.log("Deposit with account:", taker.address);

    const DV = new hre.ethers.Contract(depositvault, depositABI.abi, taker);

    DV.deposit_token(
        USDT,
        deposit_amount
    )

    const maker =  await hre.ethers.provider.getSigner(1); // deposit REXE 0x19E75eD87d138B18263AfE40f7C16E4a5ceCB585 

    const REXE = "0xEb008acbb5961C2a82123B3d04aBAD0e0EEe9266"


    const deposit_amount_2 ="100000000000000000000"

    const TOKENCONTRACT_2 = new hre.ethers.Contract(REXE, tokenabi.abi, maker);
    // Wait for approval transaction to finish
    const approvalTx_2 = await TOKENCONTRACT_2.approve(depositvault, deposit_amount_2);
    await approvalTx_2.wait();  // Wait for the transaction to be mined



    console.log("Deposit with account:", maker.address);

    const DVM = new hre.ethers.Contract(depositvault, depositABI.abi, maker);

    DVM.deposit_token(
        REXE,
        deposit_amount
    )




    /// 100 tokens each 



}



deposit()
//node depositDV.js
