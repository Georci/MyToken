var keyth = require('keythereum');
//('你想要得到私钥的账户地址'，'你keystore存放的目录（即keystore在我的data0目录下）')，这里使用的是绝对路径
var keyobj = keyth.importFromFile('6d0d470a22c15a14817c51116932312a00ff00c8', '/home/kenijima/usr/work/NFT');
var privateKey = keyth.recover('123', keyobj);//（'这个账号的密码'，keyobj）
console.log(privateKey.toString('hex'));//然后你就能够得到你的私钥了

// address:0x704b92cac7a929915f57f734a58f5255e8c7f604 key:71cf1c3121ae71b542c6e2cffff6c16da58019327fa7d1bb957d9ed5f52ff8f7
// address:0x5b7b9e5f6fab7305997dfe06bcda367c95ad8022 key:042ac8081e9725c071cc6163d47f2564f7ac4f379f3899119a9a6ed6c77f896b
// address:0x6bf884c63662ecb1b38ddc682c2ffc9f993b5ec5 key:7487a9d048b1f432f7c721d8176ba5cb633ad9a6f6cce811262d981d66761ec8
// address:0x6d0d470a22c15a14817c51116932312a00ff00c8 key:3ba5c6a17da00c75e9377e03ae98aa3dcdca7c4e537c84399125dfefa89be521