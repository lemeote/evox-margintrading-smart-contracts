
async function deposit(DV, USDT, REXE) {

    const depositvault = DV
    const taker = await hre.ethers.provider.getSigner(0); // deposit usdt  // 0x8d23Bd68E5c095B7A1999E090B2F9c20114CbBb4
  
    const contractABI = tokenabi.abi; // token abi for approvals 
    const deposit_amount = "1000000000000000"
  
    const TOKENCONTRACT = new hre.ethers.Contract(USDT, contractABI, taker);
    // Wait for approval transaction to finish
    const approvalTx = await TOKENCONTRACT.approve(depositvault, deposit_amount);
    await approvalTx.wait();  // Wait for the transaction to be mined
  
  
    console.log("Deposit with account:", taker.address);
  
    const DVault = new hre.ethers.Contract(depositvault, depositABI.abi, taker);
  
    DVault.deposit_token(
      USDT,
      deposit_amount
    )
  
    const maker = await hre.ethers.provider.getSigner(1); // deposit REXE 0x19E75eD87d138B18263AfE40f7C16E4a5ceCB585 
  
    const deposit_amount_2 = "1000000000000000"
  
    const TOKENCONTRACT_2 = new hre.ethers.Contract(REXE, tokenabi.abi, maker);
    // Wait for approval transaction to finish
    const approvalTx_2 = await TOKENCONTRACT_2.approve(depositvault, deposit_amount_2);
    await approvalTx_2.wait();  // Wait for the transaction to be mined
  
    console.log("Deposit with account:", maker.address);
  
    const DVM = new hre.ethers.Contract(depositvault, depositABI.abi, maker);
  
    await DVM.deposit_token(
      REXE,
      deposit_amount
    )
  
  
    /// 100 tokens each 
  
  
  
  }