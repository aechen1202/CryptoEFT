## CryptoETF

**許多金融領域都有類似ETF包裝商品，藉由一籃子標的去追蹤某個指數，而在區塊鏈以太坊上也應該需要有類似ETF的追蹤代幣，但是單純將原生代幣存入鑄造新的ETF代幣原生代幣鎖在合約不動很可惜，所以結合Compound將原生代幣拿去借貸賺取利息，此協議可以藉此賺取手續費，長期持有者也可以收到利息回饋等激勵前言**

## 說明
以架構而言此產品為ETF組合Token與結合Compound v2的借貸協議商品，以便使用者可以追蹤指數與領取固定利息收入
1. 角色
* Users使用者:參與指數追蹤的一般使用者，可以依指定比例原生Token存入鑄造等比的ETF Token，此ETF Token是個ERC20協議支援ERC20協議功能，使用者可以申請持有期間的利息，如果使用者需要解除此EFT Token也可以註銷此代幣因而獲得原始比例的原生代幣
1)mint鑄造:呼叫EFT Contract mint方法並且傳送原生代幣(ig.weth.wbtc)至EFT Contract，EFT Contract會立刻傳入Compound cToken Contract的mint返回對應的cToken存在EFT Contract，EFT Contract會記錄該使用者所屬的cToken與block index等資料

Users =[transfer tokens(ig.weth.wbtc)]=> ETF Contract =[transfer tokens(ig.weth.wbtc)]=> Compound cToken Contract
ETF Contract <=[transfer tokens(ig.cEth.cBtc)]= Compound cToken Contract


2)claim申請利息:呼叫EFT Contract claim方法獲得原生代幣利息

Users <=[transfer tokens(ig.wEth.wBtc)]= ETF Contract <=[transfer tokens(ig.wEth.wBtc)]= Compound cToken Contract


3)redeem解除代幣:呼叫EFT Contract redeem解除代幣，使用者會獲得應有比例的原始代幣

Users <=[transfer tokens(ig.wEth.wBtc)]= ETF Contract <=[transfer tokens(ig.wEth.wBtc)]= Compound cToken Contract

* admin管理者:管理者負責篩選好品質的原生代幣並且設定既有比例，設定完畢此ETF Token組成的原生代幣與比例則不可變更
1)ETF setting:佈署新的EFT Token後必須將比例與資料使用admin帳號在controller介面做開通

admin =set ETF=> controller Contract


2.變更

與Compound v2比較做了以下變更

* 新增EFT Token合約
* 變更利息申請方式(?)
* 移除COM Token相關治理功能
* 將comtroller改名為controller
* 於controller新增ETF Token設定相關方法
```
