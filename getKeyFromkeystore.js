var keyth = require('keythereum');
//('你想要得到私钥的账户地址'，'你keystore存放的目录（即keystore在我的data0目录下）')，这里使用的是绝对路径
var keyobj = keyth.importFromFile('704b92cac7a929915f57f734a58f5255e8c7f604', '/home/kenijima/usr/work/NFT');
var privateKey = keyth.recover('123', keyobj);//（'这个账号的密码'，keyobj）
console.log(privateKey.toString('hex'));//然后你就能够得到你的私钥了

// address:0x704b92cac7a929915f57f734a58f5255e8c7f604 key:71cf1c3121ae71b542c6e2cffff6c16da58019327fa7d1bb957d9ed5f52ff8f7