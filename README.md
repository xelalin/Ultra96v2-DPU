---
layout: post
title:  如何在Ultra96v2上整合DPU及安裝DNNDK
author: Alex Lin
---

## 前言
此篇將快術帶領各位如何在Ultra96 v2上整合DPU IP及安裝DNNDK，並佈署一個Resnet50的分類網路及人臉偵測的Densebox檢測網路

## 環境需求
以下為使用Xilinx DPU IP加速深度學習演算法所需的軟體及硬體工具

### 軟體工具　

- Vivado&reg; Design suite 2019.1
- 已安裝好Ultra96 v2的Board files ([安裝說明](https://www.element14.com/community/servlet/JiveServlet/downloadBody/92692-102-1-381948/Installing-Board-Definition-Files_v1_0_0.pdf))
- Xilinx SDK 2019.1
- Petalinux 2019.1

### 硬體工具　

- Ultra96 v2 board
- 12V@4A 電源供應器
- MicroUSB to USB-A cable
- AES-ACC-USB-JTAG board
- SD card(FAT32格式)
- DisplayPort 螢幕(選項)
- Mini-DisplayPort to DisplayPort cable(選項)
- USB Webcam(選項)

首先從我的[Github](https://github.com/xelalin/Ultra96v2-DPU)下載本地，如下所示

```
git clone https://github.com/xelalin/Ultra96v2-DPU.git
```

![figure](/assets/posts/2019-10-10/Ultra96v2_DPU.png)

目錄說明：
- files: petalinux/Yocto recipes, and source code for SDK, etc. 
- hsi: 存放Vivado Design Suite export出的HDF檔案，給Petalinux使用
- prebuilts: 存放pre-build的`.hdf`，`BOOT.BIN`，`image.ub`以及application的`.elf`
- sdk_workspace: 空目錄用來來指定SDK的workspace
- vivado: Vivado Design suite工作目錄，內含`u96_dpuv2.0_2018.2.tcl`用來產生Vivado Block Design
- sdcard: 用來存放SD Image,但因超過Github的限制，所以是空的

另外從Xilinx官網下載DPU TRD並且解壓縮後的目錄結構，如下

![figure](/assets/posts/2019-10-10/DPU_TRD.png)

透過TRD BSP建立一個petalinux project得到相關的Yocto recipes,以利後續的開發流程

```
source /opt/pkg/petalinux/2019.1/settings.sh
cd zcu102-dpu-trd-2019-1-timer
petalinux-create -t project -n dpu_bsp -s ./apu/dpu_petalinux_bsp/xilinx-dpu-trd-zcu102-v2019.1.bsp
tree dpu_bsp/ -L 3
```

![figure](/assets/posts/2019-10-10/dpu_bsp.png)


將以下相對應的檔案及目錄，複製到Ultra96v2-DPU目錄下

```
cp -rp ./zcu102-dpu-trd-2019-1-timer/pl/srcs/dpu_ip/dpu ./Ultra96v2-DPU/ip_repo/
```

將Yocto相對應recipes複製到files目錄下:

```
cp -rp zcu102-dpu-trd-2019-1-timer/dpu_bsp/project-spec/meta-user/recipes-apps/ Ultra96v2-DPU/files/
cp -rp zcu102-dpu-trd-2019-1-timer/dpu_bsp/project-spec/meta-user/recipes-core/ Ultra96v2-DPU/files/
cp -rp zcu102-dpu-trd-2019-1-timer/dpu_bsp/project-spec/meta-user/recipes-modules/ Ultra96v2-DPU/files/
```

完成後，目錄結構如下：
![figure](/assets/posts/2019-10-10/Ultra96v2_DPU_TRD.png)

## Projectg說明

簡單用一張圖示說明設計流程：
![Design Flow](/assets/posts/2019-10-10/design_flow.png "Design Flow")

從上圖得知，完成佈署一個深度網路神經系統包含以下四個開發步驟：
- Vivado Design Suite: 透過Vivado IPI整合DPU IP到FPGA上
- PetaLinux: 建立一個Linux得執行環境，並且整合DPU的driver，runtime以及utilities
- Xilinx DNNDK: 將caffe或是Tensorflow的模型，編譯成DPU的可執行檔.elf 
- Xilinx SDK: 編譯出一個Linux環境的可執行檔.elf

### Vivado Design Suite的步驟
1. 建立一個Ultra96 v2 board的new project
2. 加入DPU IP到此Project中
3. 在IP Integrator中，使用`.tcl script`建立Block Design
4. 解釋DPU的配置及連接
5. 產生bitstream
6. Export一個`.hdf` file

### Petalinux的步驟
1. 使用"Template Flow."建立一個Petalinux new project
2. 加入Yocto Recipes以及更改recipe
3. Import `.hdf`
4. 在Petalinux中配置Ultra96 v2 規格硬體
5. 在root filesystem中加入必要的packages
6. 在device-tree中加入DPU的配置
7. build project
8. Create a boot image

### Xilinx DNNDK
下圖為DNNDK的開發流程圖，此文直接使用已經經過`dnnc` compiler出的`.elf` files，筆者將在另一篇文章詳細說明，如何從以訓練好的模型透過DNNDK產生DPU可執行的`.elf`檔，如以下圖是所示:
![DNNDK Design Flow](/assets/posts/2019-10-10/dnndk_design_flow.png "DNNDK Design Flow")

### Xilinx SDK
1. 建立resent50和face detection的應用程式
2. Import由`dnnc`所產生出的`.elfs`
3. 更新sysroot上application的選項，包含必要的librries...etc
4. 產生 resnet50和face detection的應用程式

## 在Vivado Design suite上建立一個硬體平台

### Step 1: 在Vivado&reg; Design Suite建立一個新的Project
1. 呼叫Vivado

```
cd <PROJ ROOT>/vivado/
vivado
```

2. 利用Ultra96 v2 board files建立新project

     - Project Name: **project_1**
     - Project Location: `<PROJ ROOT>/vivado`
     - Do not specify sources
     - Select **Ultra96v2 Evaluation Platform**

      **注意:** 如在Boards tab中選不到**Ultra96v2 Evaluation Platform**，那麼請先參考[Installing Board Definition for Ultra96v2](https://www.element14.com/community/servlet/JiveServlet/downloadBody/92692-102-1-381948/Installing-Board-Definition-Files_v1_0_0.pdf) 先將Board files安裝好
  
![Board Files](/assets/posts/2019-10-10/u96_board_files.png "Board Files")

3. Click **Finish**.

### Step 2: 加入DPU IP repository

1. 在Project Manager點擊**IP Catalog**

2. 在**Vivado Repository**典籍滑鼠右鍵然後選擇**Add Repository**.

3. 瀏覽目錄點選到**<PROJ ROOT>/ip_repo**

![IP Catalog](/assets/posts/2019-10-10/dpu_ip_repos_1.png "IP Catalog")

### Step 3: 建立Block Design

1. 打開TCL Console tab,確認工作目錄為`<PROJ ROOT>/vivado`輸入以下命令

     ```
     source u96_dpuv2.0_2018.2.tcl
     ```
![TCL Command](/assets/posts/2019-10-10/tcl_cmd_dpu.png "TCL Command")

2. 當Block Design完成後，在source tab的 **design_1** 上按滑鼠右鍵選擇**Create HDL Wrapper**
3. 同意Default的選項

![Block Design](/assets/posts/2019-10-10/create_hdl_wrapper.png "Block Design")

4. 驗證設計
![Validate Design](/assets/posts/2019-10-10/validate_design.png "Validate Design")

### Step 4: 複製 pre-built `.hdf` 到 `hsi`目錄下

為了節省時間，我們可以跳過產生bitstream的步驟，手動將pre-built的.`.hdf`文件導出到hsi的目錄中。 要使用pre-built的選項，請執行以下命令將pre-bulit`.hdf`複製到hsi中：

```
cd <PROJ ROOT>
cp prebuilts/design_1_wrapper.hdf hsi
```
完成此步驟後，你可以直接跳到Ｐetalinux的部份

### Step 5: 產生bitstram
1. 點擊 **Generate Bitstream**
![ Generate Bitstream](/assets/posts/2019-10-10/generate_bitstream.png "Generate Bitstream")
2. 接受預設選項

### Step 6: Export Hardward

  當Bitstream成功的生成後，請執行以下步驟來export `.hdf`以供PetaLinux使用：
  1. 點擊 **File** > **Export** > **Export Hardware**.

  2. 確認Export有勾選 "include the bitstream"

  3. Export the hardware platform to `<PROJ ROOT>/hsi`.

  4. 點擊 **OK**.

     ![Export Hardware](/assets/posts/2019-10-10/export_hdf.png "Export Hardware")

## 在Petalinux下，產生Linux Platform
從Viviado&reg; Design Suite　export出的硬體定義文件(`.hdf`)，就可以開始Petalinux設計流程了。此時，你應該已經把`.hdf`export到`<PROJ ROOT>/hsi`目錄了

**Tip:** 為了加快輸入速度，我以將相關命令列指令放在`<PROJ ROOT>/files/commands.txt`，你可以是用複製和貼上，一步一步的執行。

### Step 1: 建立一個PetaLinux的Project

利用以下命令創建一個Petalinux的project，從Zynq&reg; UltraScale+樣板開始,並不是使用一個以存在的BSP，並且專案檔名為petalinux
```
source /opt/xilinx/petalinux/2018.2/settings.sh
cd  <PROJ ROOT>
petalinux-create -t project -n petalinux --template zynqMP
cd petalinux
```

### Step 2: 複製Yocto recipes到PetaLinux的專案

這個步驟,主要是將Yocto recipes加入到客製化的Kernel中以及加入dnndk相關檔案。

**注意:** 在執行以下命令前，確認是否位於 `<PROJ ROOT>/petalinux`的目錄中。

1. 加入DPU utilities, libraries, and header files到root file system.

```
cp -rp ../files/recipes-apps/dnndk/ project-spec/meta-user/recipes-apps/
```

2. 加入DPU driver kernel module.

```
cp -rp ../files/recipes-modules project-spec/meta-user
```

3. 加入一個Linux啟動時可自動運行的scripts.

```
cp -rp ../files/recipes-apps/autostart project-spec/meta-user/recipes-apps/
```

4. 加入一個“ bbappend”，以便執行各種操作，例如自動插入DPU　Driver，自動掛載SD卡，修改PATH等

```
cp -rp ../files/recipes-core/base-files/ project-spec/meta-user/recipes-core/
```

## Step 3: 將PetaLinux配置為安裝dnndk文件

編輯/petalinux-image-full.bbappend檔案

```
vi project-spec/meta-user/recipes-core/images/petalinux-image-full.bbappend
```

  加入以下這三行到petalinux-image-full.bbappend:

```
IMAGE_INSTALL_append = " dnndk"
IMAGE_INSTALL_append = " autostart"
IMAGE_INSTALL_append = " dpu"
```

## Step 3: 將PetaLinux指向從Vivado Design Suite導出的`.hdf`文件

1. 使用以下命令打開PetaLinux項目配置的GUI:

```
petalinux-config --get-hw-description=../hsi
```

2. 將 serial port設成`psu_uart_1`.

```
Subsystem AUTO Hardware Settings->Serial Settings->Primary stdin/stdout = psu_uart1
```

**注意:** Ultra96 v2 board的UART連接到USB JTAG/UART板子為`psu_uart_1`.

  ![Subsystem AUTO Hardware Settings](/assets/posts/2019-10-10/plnx_hw_settings.png "Subsystem AUTO Hardware Settings")

3. 選擇 **Ultra96 Machine**.

```
DTG Settings -> MACHINE_NAME = zcu100-revc
```

**注意:** Ultra96原來叫名為zcu100.

**Tip:** 使用倒退鍵刪除預設文字, 然後再加入**zcu100-revc**.

這樣.系統就會使用Ultra96指定的device-tree檔案.

![DTG Settings](/assets/posts/2019-10-10/DTG_settings.png "DTG Settings")

4. 跳出及儲存.這個步驟會需要一點時間建立.

## Step 5: 配置rootfs

使用以下命令打開PetaLinux rootfs配置的GUI.

```
petalinux-config -c rootfs
```

1. Enable 以下列出的項目:

   **Note:** 不要 enable dev跟dbg packages.

   **Petalinux Package Groups ->**

   - matchbox
   - opencv
   - v4lutils
   - x11

   **Apps ->**

      - autostart

   **Filesystem Packages ->**   

   - libs->libmali-xlnx->libmali-xlnx

   **Modules ->**

      - dpu

   **User Packages ->**

      - dnndk

![rootfs Settings](/assets/posts/2019-10-10/rootfs_settings.png "rootfs Settings")


2. 退出及儲存.

## Step 6:  配置Kernel
使用以下命令打開PetaLinux kernel配置的GUI
  ```
  petalinux-config -c kernel
  ```
1. 退出及儲存.

## Step 7: 在device tree中加入DPU
petalinux 2019.1 device-tree generator還位支持DPU。因此，我們需要根據我們的硬體配置，手動將DPU加入到device-tree node
在`project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi`最後一行,加入以下的文字

![DPU Integration](/assets/posts/2019-10-10/dpu-device-tree.png "DPU Integration")

#### Interrupt數值

| PS Interface    |  GIC IRQ#  |  Linux IRQ  |
|-----------------|:----------:|:-----------:|
| PL_PS_IRQ1[7:0] |  143:136   |   111:104   |
| PL_PS_IRQ0[7:0] |  128:121   |   96:89     |

要計算中斷號（即Linux IRQ，請從GIC IRQ號中減去32。例如，在Vivado項目中，我們連接到GIC IRQ編號為121（根據TRM）的“PL_PS_IRQ0 [0]”。 因此，Linux IRQ號為121-32 = 89（0x59）。

Interrupt的三種定義如下：
<table>
<tr>
<td><b>Interrupt</b></td>
<td><b>Description</b></td>
</tr>
<tr>
<td>1st Cell</td>
<td>0 = Shared Peripheral Interrupt (SPI)<br>1 = Processor to Processor Interrupt (PPI)</td>
</tr>
<tr>
<td>2nd Cell</td>
<td>Linux Interrupt number</td>
</tr>
<tr>
<td>3rd Cell</td>
<td>1 = rising edge<br>2 = falling edge<br>4 = level high<br>8 = level low</td>
</tr>
</table>

## Step 8: 產生kernel和root file system

```
petalinux-build
```

## Step 9: 建立boot image

```
cd images/linux

petalinux-package --boot --fsbl zynqmp_fsbl.elf --u-boot u-boot.elf /
--pmufw pmufw.elf --fpga system.bit --force
```

## Step 10: 產生sysroot
在XSDK中編譯一個應用程式，需要指定sysroot來針對root file system中，所使用的一些軟件包所提供的libraries/header來產生執行檔

#### 安裝Pre-Built SDK
完成整個XSDK所需的sysroot編譯時間需要幾個小時，因此，提供一個已pre-built SDK以節省時間
這個pre-built SDK從[這裡](http://www.xilinx.com/support/documentation/sw_manuals/xilinx2019_1/ug1350-design-files_v2.zip)下載後，解壓縮然後複製`sdk.sh`到`../files`

使用以下命令安裝pre-built sdk
```
cd <PROJ ROOT>/petalinux
petalinux-package --sysroot -s  ../files/sdk.sh
```

#### 重新建立SDK
如果想要完成整個過程以重新建立SDK，請使用以下步驟：

1. 執行以下命令以創建 Yocto SDK以及複製到`<PROJ ROOT>/petalinux/images/linux/sdk.sh`:

```
petalinux-build --sdk
```

2. 執行以下命令解壓縮以及安裝所產生的SDK跟sysroot到指定的目錄:

```
petalinux-package --sysroot -d <directory>
```
**Note:** 如果你沒有指定目錄(`-d`), 預設會將SDK安裝在`images/linux/sdk`

![SDK](/assets/posts/2019-10-10/sdk-sysroot.png "SDK")

# 使用Xilinx SDK產生Machine Learning的應用程式
依照以下步驟，使用Xilinx SDK來建立兩個使用DPU的機器學習應用程式：

## Step 1: 啟動Xilinx SDK
執行以下命令以啟動Xilinx SDK GUI：
```
xsdk
```
當XSDK GUI打開時，瀏覽至`<PROJ ROOT>/sdk_workspace`的空白workspace
![SDK Workspace](/assets/posts/2019-10-10/sdk_workspace.png "SDK Workspace")

## Step 2: 創建新的Application Project

按照以下步驟，創建新的Application Project：

1. 點擊主選單 **File** 然後選擇 **New Application Project**

2. 輸入以下參數:
      - Name: **resnet50**
      - OS Platform: **Linux**
      - Processor Type: **psu_cortexa53**
      - Language: **C++**


3. 點擊 **Next**

4. 選擇 **Empty Application**

5. 點擊 **Finish**.

![New Project](/assets/posts/2019-10-10/new_project.png "New Project")

## Step 3: Import Source Files and Model .elf Files

按照以下步驟，import source files和model .elfs檔案:

1. 點擊主選單 **File** 然後 **Import** -> **General** -> **Filesystem**.
2. 瀏覽至`<PROJ ROOT>/files/resnet50`.
3. 點擊 **OK**.
4. 選擇 **main.cc**
5. 確定`Into Folder`已經設為 **resnet50/src**.
6. 點擊 **Finish**, 以及允許覆寫`main.cc`.
7. 依同樣的步驟 import DPU的 model `.elf`, `dpu_resnet50_0.elf`

  **Note:** 這個models是事先使用使用DNNDK編譯好的,並放在`<PROJ ROOT>/files/resnet50/B1152_1.4.0`,你可以直接使用.

![New Application](/assets/posts/2019-10-10/resnet50_src.png "New Application")


## Step 4: 更新 Application Build Settings

按照以下步驟，更新application build settings:

1. 在**resnet50 application**滑鼠右鍵，然後選擇 **C/C++ Build Settings**.

2. 在 **C/C++ Build** -> **Environment**, 加入SYSROOT變數以及指向sysroot的位置. 比如上面我產生出的sysroot路徑:

 ```
 ${workspace_loc}/../petalinux/images/linux/sdk/sysroots/aarch64-xilinx-linux
 ```

  ![Environment Variables](/assets/posts/2019-10-10/sysroot_env.png "Environment Variables")  

3. 將 compiler和linker指向SYSROOT:
    - g++ linker settings:

        **Miscellaneous** -> **Linker Flags** : `--sysroot=${SYSROOT}`

        ![Linker Flags](/assets/posts/2019-10-10/g_link_sysroot.png "Linker Flags")
    - g++ compiler settings:

        **Miscellaneous** -> **Other Flags**:  `--sysroot=${SYSROOT}`
        ![Other Flags](/assets/posts/2019-10-10/g_compiler_sysroot.png "Other Flags")
4. 在 g++ linker libraries tab, 加入以下 libraries:
    - n2cube
    - dputils
    - pthread
    - opencv_core
    - opencv_imgcodecs
    - opencv_highgui

      ![Linker libraries](/assets/posts/2019-10-10/g_linker_lib.png "Linker libraries")

5. 在 **g++ linker** -> **Miscellaneous**, 加入 model `.elfs` 到 **Other Objects**.

6. 從 `resnet50/src directory` 加入 `dpu_resnet50_0.elf`
 **注意:** 您可以點擊**Workspace**以瀏覽至所需的對象，如下圖所示:

  ![File Selection](/assets/posts/2019-10-10/object_select.png "File Selection")

  ![Other Objects](/assets/posts/2019-10-10/fd_other_object.png "Other Objects")

7. 點擊 **OK**.
8. 在 **resnet50** application下按滑鼠右鍵，然後選擇 **Build Project**.


## Step 5:  創建 Face Detection Application
執行下列步驟，建立face detection的應用程式


1. 重覆Step 2流程，而Name為 **face_detection**，其餘一樣

2. 重覆Step 3流程，加入source file為<PROJ ROOT>/files/face_detection/face_detection.cc

3. 刪除`main.cc`

4. 從`<PROJ ROOT>/files/face_detection/B1152_1.4.0`加入`dpu_densebox.elf`

5. 設定SYSROOT環境變數

6. 在compiler中，指定SYSROOT路徑和設定linker miscellaneous

7. 加入以下libraries:
    - n2cube
    - dputils
    - opencv_core
    - opencv_imgcodecs
    - opencv_highgui
    - opencv_imgproc
    - opencv_videoio
    - pthread
	
	![FR Linker libraries](/assets/posts/2019-10-10/face_detection_libraries.png "FR Linker libraries")

8. 對g++ Linker Miscellaneous -> **Other Objects**，選擇`face_detection/src/dpu_densebox.elf`


9. 點擊 **OK**

10. 在**face_detection** application下,按滑鼠右鍵然後選擇**Build Project**

# 使用Ultra96 v2 board驗證

## 設定 Ultra96 v2

依照以下步驟，設定Ultra96 v2:

1. 連接上 12V power supply.
2. 連接上 AES-ACC-USB-JTAG board.
3. 連接上 Camera 子卡到Ultra96 v2 (選項)
4. 將 microUSB cable 連接到 AES-ACC-USB-JTAG 和 PC.
5. 將第二條microUSB　cable從Ultra96 v2 USB3.0 connector連接到PC以進行連網
6. 使用miniDiSplay cable 連接Ultra96 v2和DisplayPort Monitor (選項)
7. 連接一個 USB webcam 到其中一個 host USB ports (選項)
8. 準備一個MicroSD card,並partition成FAT32

      ![Ultra96](/assets/posts/2019-10-10/u96v2_settings.png "Ultra96")

# 在Ultra96 v2上執行應用程式

接下來，我們將所有測試集圖像到Host PC上的SD card暫存目錄，然後再一次將所有檔案複製SD card 中。`PROJ_ROOT`目錄下有一個sdcard目錄內已包含測試集圖像，Face detection和resnet50三個目錄測試圖像位於/ sdcard / common / image500_640_480目錄中。

## Step 1: 複製檔案至SD card
執行下列步驟，複製檔案至SD card:

1. 複製 `<PROJ ROOT>/petalinux/images/linux/image.ub` 及 `BOOT.BIN` 到 `sdcard` 目錄下.
2. 複製 `<PROJ_ROOT>/sdk_workspace/resnet50/Debug/resnet50.elf` 到 `sdcard/resnet50` 目錄下.
3. 複製 `<PROJ_ROOT>/sdk_workspace/face_detection/Debug/face_detection.elf` 到 `sdcard/face_detection` 目錄下.

   你可以用複製和貼上執行以下命令: 

```
cd <PROJ ROOT>
cp petalinux/images/linux/image.ub sdcard
cp petalinux/images/linux/BOOT.BIN sdcard
cp sdk_workspace/resnet50/Debug/resnet50.elf sdcard/resnet50/
cp sdk_workspace/face_detection/Debug/face_detection.elf  sdcard/face_detection/`
```

4. 在Host PC上將 `sdcard` 目錄上所有的檔案複製到microSD card.

## Step 2:	Boot the Ultra96
將micro SD card放置到Ultra96 v2 board，使用以下的帳號及密碼登入:

- username = **root**
- password = **root**

## Step 3: 初始化顯示畫面

有兩種方法可以顯示人臉檢測應用程式的結果。您可以將帶有DisplayPort的螢幕直接連接到Ultra96 v2 board，也可以通過網絡將video streaming傳輸到連接的PC，透過x-windows顯示。

### 螢幕

執行以下命令:

```
v4l2-ctl --set-fmt-video=width=640,height=480,pixelformat=UYVY
export DISPLAY=:0.0
xrandr --output DP-1 --mode 800x600
xset s off -dpms
```

**注意:** 使用 `xrandr` 設定適合的解析度. 當解析度設為1920x1080時，執行應用程式時，螢幕會閃爍，此時Memory頻寬需求高，DPU吃掉比較多的memory以至於顯示閃爍，可以透過程式設定優先權解決.  

### 透過網路連接到Host PC

有兩種方法可以通過網絡連接到Ultra96 v2 board：

1. USB Ethernet adapter

   * 將 USB Ethernet adapter連接到 Ultra96 v2上USB Host ports，然後連接到Host PC上的網路孔.

2. USB 虛擬網路卡(RNDIS/Ethernet Gadget):

   *  使用micro USB連接Host PC及Ultra96 v2 USB3.0 並在Host PC將 RNDIS enable.

   * 開機後執行以下命令，開啟網路功能:

     ```
     modprobe g_ether
     ifup usb0
     ```

#### 透過SSH連接並使用X11 forwarding將顯示畫面轉換到Host PC上:

在Windows上，使用有提供X-server的SSH client軟體（例如[MobaXterm]（https://mobaxterm.mobatek.net/））通過網絡連接到target board。 確定有enable X-server，以及正確設置DISPLAY環境變量。 啟動應用程序時，輸出將轉發回Host PC並顯示在另一個視窗上。

在Linux環境下(或是Windows命令列)，可以使用以下命令:

* ssh -X root@[IP address of Ultra96].

## Step 4:	執行 Resnet50

使用以下命令，變換目錄到`resnet50`並且執行應用程式

    ```
    cd /media/card/resnet50
    ./resnet50.elf
    ```
	
執行結果:
　　![Resnet50](/assets/posts/2019-10-10/resnet50_results.png "Resnet50")

## Step 5:	執行 face detection

使用以下命令，變換目錄到`face_detection`並且執行應用程式
    ```
    cd /media/card/face_detection
    ./face_detection.elf
	```

這是直接拿camera照有人臉的照片，使用的是RGB camera演算法，沒有深度資料，所以無法分辦真實人臉還是照片:
　　![Face_detection](/assets/posts/2019-10-10/fd_results.png "Face_detection")


**注意:** 如果你看到 “Open camera error!”, 試著重新插拔USB camera.如果還是無法識別, 那麼請從新開機, 兩種方法都不行時，那就更換一個USB camera

## 相關參考資料
1. [Ultra96 v2硬體使用手冊](https://www.element14.com/community/docs/DOC-92688/l/ultra96-v2-hw-user-guide-rev-1-0-v10preliminary?ICID=ultra96v2-datasheet-widget)
2. [Ultra96 v2電路圖](https://www.avnet.com/opasdata/d120001/medias/docus/193/Ultra96-V2%20Rev1%20Schematic.pdf)
3. [DNNDK使用手冊](https://www.xilinx.com/support/documentation/sw_manuals/ai_inference/v1_6/ug1327-dnndk-user-guide.pdf)
4. [AI SDK使用手冊](https://www.xilinx.com/support/documentation/user_guides/ug1354-xilinx-ai-sdk.pdf)
5. [DPU IP產品手冊](https://www.xilinx.com/support/documentation/ip_documentation/dpu/v3_0/pg338-dpu.pdf)

