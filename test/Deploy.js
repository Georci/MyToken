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
    const name = "MyToken";
    const symbol = "MTK";
    const initialOwner = "0x6d0d470a22c15a14817c51116932312a00ff00c8";
    const gaslimit = 5000000;

    console.log("start deploying...")

    const [abi, bytecode] = await get_abi_bytecode("NFT.sol", "MyToken")
    console.log(abi)
    console.log(bytecode)
    var provider = new ethers.JsonRpcProvider("http://localhost:8545")

    var deployer_private_key =
        "0x3ba5c6a17da00c75e9377e03ae98aa3dcdca7c4e537c84399125dfefa89be521"

    var tx = {
        gasLimit: 5000000n
    }

    var wallet = new ethers.Wallet(deployer_private_key, provider)
    //   var Balance = await provider.getBalance(wallet.address)
    //   console.log("Balance of deployer is :", Balance)

    // deployg
    var MyTokenFactory = new ethers.ContractFactory(abi, bytecode, wallet)

    var MyToken = await MyTokenFactory.connect(wallet).deploy(name, symbol, initialOwner, { tx })
    await MyToken.waitForDeployment();

    console.log("MyToken contract deployed at address:", MyToken.target)
    console.log("MyToken contract balance :", await provider.getBalance(MyToken.target))
}

async function main() {
    await deploy();
}

main()




