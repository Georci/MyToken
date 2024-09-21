const fs = require("fs")
const ethers = require("ethers")
const { exec } = require("child_process")

function get_abi_bytecode(file_path, contract_name) {
  return new Promise((resolve, reject) => {
    var abi
    var bytecode

    exec("solcjs --abi " + file_path, (error, stdout, stderr) => {
      if (error) {
        console.error(`执行命令错误: ${error}`)
        reject(error)
        return
      }

      // 读取文件中的abi内容
      var abiFilePath =
        file_path.split(".")[0] +
        "_" +
        file_path.split(".")[1] +
        "_" +
        contract_name +
        ".abi"
      fs.readFile(abiFilePath, "utf-8", (error, data) => {
        if (error) {
          console.error(error)
          reject(error)
          return
        }
        abi = JSON.parse(data)

        exec("solcjs --bin " + file_path, (error, stdout, stderr) => {
          if (error) {
            console.error(`执行命令错误: ${error}`)
            reject(error)
            return
          }

          var bytecodeFilePath =
            file_path.split(".")[0] +
            "_" +
            file_path.split(".")[1] +
            "_" +
            contract_name +
            ".bin"
          fs.readFile(bytecodeFilePath, "utf-8", (error, data) => {
            if (error) {
              console.error(error)
              reject(error)
              return
            }
            bytecode = data
            resolve([abi, bytecode])
          })
        })
      })
    })
  })
}

// 部署被攻击合约
async function deploy() {

  console.log("start deploying...")

  const [abi, bytecode] = await get_abi_bytecode("NFT.sol", "MyToken")
  console.log(abi)
  console.log(bytecode)
  var provider = new ethers.JsonRpcProvider("http://localhost:8545")

  var deployer_private_key =
    "0x71cf1c3121ae71b542c6e2cffff6c16da58019327fa7d1bb957d9ed5f52ff8f7"

  // tx: Making sure FreeMint has 10 ether.
//   var sendValue = ethers.parseEther("10") // 10 ether
//   var tx = {
//     value: sendValue,
//     gas: 100000
//   }

  var wallet = new ethers.Wallet(deployer_private_key, provider)
//   var Balance = await provider.getBalance(wallet.address)
//   console.log("Balance of deployer is :", Balance)

  // deployg
  var MyTokenFactory = new ethers.ContractFactory(abi, bytecode, wallet)

  var MyToken = await MyTokenFactory.connect(wallet).deploy()
  await MyToken.waitForDeployment();

  console.log("MyToken contract deployed at address:", MyToken.target)
  console.log("MyToken contract balance :", await provider.getBalance(MyToken.target))
}

async function main() {
  await deploy();
}

main()



