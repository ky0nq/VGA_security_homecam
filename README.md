# VGA_security_homecam

**OV7670 기반 비접촉 패턴 인증 및 FPGA 영상 처리 시스템**

파란색 마커의 이동 경로로 사용자를 인증하고, 인증 결과에 따라 홈캠 영상의 잠금 상태를 제어하는 FPGA 프로젝트입니다. Basys 3 보드 2대에 인증 단말과 홈캠을 각각 구성했으며, 카메라 입력부터 패턴 판정, 영상 필터, VGA 출력까지 SystemVerilog로 구현했습니다.

LOCK 상태에서는 홈캠 영상을 블러 처리하고, 인증에 성공하면 원본 영상과 필터·확대 기능을 사용할 수 있습니다. 두 보드는 **115200 bps UART로 인증 상태와 조작 명령을 교환**하며, 영상은 각 보드 내부에서 처리합니다.

| 프로젝트 기간 | 교육 과정 | 팀 구성 |
|---|---|---|
| 2026.08.31 ~ 2026.09.08 | 온디바이스 AI 시스템반도체 설계 2기 | 6명 |

[프로젝트 폴더 구조](#프로젝트-폴더-구조) · [시스템 구조](#시스템-아키텍처) · [개발 사양](#개발-환경-및-사양) · [핵심 설계](#핵심-설계) · [조작 방법](#조작-방법) · [검증](#검증) · [구현 결과](#설계-개선과-구현-결과)

## 팀 및 담당 역할

**우리집 이제 Safe조?**

| 팀원 | 담당 역할 |
|---|---|
| 이나경 | 팀장·일정 관리, UART 통신, Top 통합 및 시뮬레이션 |
| 공경환 | 마커 추적 및 AUTH PATH, 인증 화면 UI, 발표 |
| 선우정욱 | Zoom, Top 통합, Top System UVM 검증 |
| 신민지 | 블러·색상 필터, VIDEO PATH, 시연 영상 |
| 정광근 | Control Unit, 데이터패스 통합, 카메라·VGA, Board 1·2 UVM 검증 |
| 조강혁 | 카메라·VGA UVM 검증 |

## 프로젝트 폴더 구조

GitHub에는 기능별 RTL과 검증 소스를 정리하고, 최종 제출 패키지에는 보드별 Vivado 프로젝트와 구현 결과를 포함했습니다.

```text
VGA_security_homecam/
├── BOARD_1/                         # 인증 단말 RTL
│   ├── system_top.sv
│   ├── auth_path.sv
│   ├── control_unit.sv
│   ├── board1_video_path.sv
│   └── uart_packet_controller.sv
├── BOARD_2/                         # 홈캠 영상 처리 RTL
│   ├── OV7670_top.sv
│   ├── vga_cam.sv
│   ├── video_path.sv
│   ├── gaussian_filter.sv
│   └── uart_link.sv
├── Tb/                              # 보드 간 제어 시나리오
├── UVM/
│   ├── OV7670_VGA/
│   │   ├── scenario1/               # Camera·VGA·SCCB UVM
│   │   └── scenario2/               # Predictor·Scoreboard 기반 UVM
│   └── Top/                        # Top System UVM
└── README.md
```

위 트리는 핵심 파일만 표시했습니다. [`BOARD_1`](https://github.com/ky0nq/VGA_security_homecam/tree/main/BOARD_1)과 [`BOARD_2`](https://github.com/ky0nq/VGA_security_homecam/tree/main/BOARD_2)에 세부 RTL을, [`Tb`](https://github.com/ky0nq/VGA_security_homecam/tree/main/Tb)와 [`UVM/OV7670_VGA`](https://github.com/ky0nq/VGA_security_homecam/tree/main/UVM/OV7670_VGA)에 검증 소스를 정리했습니다.

## 주요 기능

- **비접촉 패턴 인증:** 파란색 마커의 Bounding Box 중심을 3×3 Grid에 매핑하고, Grid 진입 순서를 등록 패턴과 비교합니다.
- **인증 화면 시각화:** 격자, 마커 이동 경로, 화면 테두리와 라벨을 VGA 영상 위에 표시합니다.
- **잠금 상태에 따른 영상 제어:** LOCK에서는 블러를 적용하고, UNLOCK에서는 원본·색상 필터·밝기 효과를 선택합니다.
- **선택 영역 확대:** 전체 영상 보기와 4분면 중 한 영역을 확대하는 Zoom을 제공합니다.
- **자동 재잠금 및 시도 제한:** 약 10초간 UART 명령을 받지 않으면 재잠금하고, 인증 3회 실패 시 60초 Lockout을 적용합니다.
- **계층별 검증:** 영상 경로는 UVM과 Golden Reference로, 보드 간 제어 경로는 시나리오 Testbench로 검증합니다.


## 시스템 아키텍처

| 구분 | Board 1 · 인증 단말 | Board 2 · 홈캠 |
|---|---|---|
| Top module | [`system_top`](https://github.com/ky0nq/VGA_security_homecam/blob/main/BOARD_1/system_top.sv) | [`OV7670_top`](https://github.com/ky0nq/VGA_security_homecam/blob/main/BOARD_2/OV7670_top.sv) |
| 영상 입력 | 인증용 OV7670 | 홈캠용 OV7670 |
| 핵심 처리 | 마커 추적, 패턴 인증, 사용자 입력 처리 | 블러, 색상·효과 필터, Zoom |
| VGA 화면 | 인증 Grid, 추적 경로, 단말기 UI | 잠금 상태에 따른 홈캠 영상 |
| UART 송신 | 인증 상태 및 조작 명령 | 자동 재잠금 알림 `0x80` |
| UART 수신 | 재잠금 상태 반영 | 명령 디코딩 및 기능 제어 |

<img width="1786" height="1263" alt="Top-Top drawio" src="https://github.com/user-attachments/assets/9c786388-59dc-495d-b9a4-abca6fbcc1cf" />

### 동작 순서

1. 두 보드를 초기화하고 OV7670 설정을 완료합니다. 홈캠은 LOCK 상태의 블러 영상을 출력합니다.
2. 인증 단말에서 인증 스위치를 켜고 파란색 마커로 등록 패턴을 입력합니다.
3. 인증 성공 시 Board 1이 Unlock 패킷을 보내고, Board 2가 블러를 해제합니다.
4. 버튼과 스위치로 필터 그룹, 필터 효과, Zoom 영역을 선택합니다.
5. 약 10초간 명령이 수신되지 않으면 Board 2가 재잠금하고 `0x80`을 반환하여 두 보드의 상태를 맞춥니다.

## 개발 환경 및 사양

| 항목 | 사양 |
|---|---|
| FPGA 보드 | Digilent Basys 3 × 2 |
| FPGA 디바이스 | Xilinx Artix-7 |
| 설계 언어 | SystemVerilog |
| FPGA 개발 도구 | Vivado 2020.2 |
| 검증 도구 | Vivado Simulator, Synopsys VCS/UVM, Verdi, Python |
| 시스템 클록 | 100 MHz |
| 카메라 | OV7670 × 2, 8-bit 병렬 데이터 입력 |
| 카메라 설정 | SCCB 100 kHz, Write Address `0x42` |
| Frame Buffer | 보드별 320×240×16-bit, RGB565 |
| VGA 출력 | 640×480, RGB444 |
| 보드 간 통신 | UART 115200 bps, 8N1, LSB first |
| 사용자 입력 | Basys 3 스위치 및 푸시 버튼 |

## 핵심 설계

### 1. 마커 추적과 패턴 인증

인증 경로는 색상 검출, 위치 계산, 입력 안정화, 패턴 판정을 분리해 구성했습니다.

```text
OV7670 RGB565
    → Blue Threshold
    → Bounding Box / Center
    → 3×3 Grid Mapper
    → Grid Stabilizer
    → Clock Domain Crossing
    → Pattern Authentication FSM
    → Pass / Fail
```

**색상 및 위치 검출**

RGB565를 공통 5-bit 채널 기준으로 비교해 `B ≥ 20`, `B ≥ R + 10`, `B ≥ G + 10`을 만족하는 픽셀을 검출합니다. 파란색 픽셀이 50개 이상일 때 검출 영역을 유효하게 취급하며, 영역의 최소·최대 좌표로 Bounding Box 중심을 계산합니다.

**Grid 입력 안정화**

중심 좌표를 1~9번 Grid에 매핑합니다. 같은 Grid가 **3프레임 연속 유지될 때** 입력을 확정하고, 동일 Grid에 머무르는 동안의 중복 진입 이벤트를 억제합니다. 카메라 픽셀 클록과 시스템 클록 사이의 신호 전달에는 동기화 플립플롭과 Toggle 기반 이벤트 전달 구조를 사용합니다.

**패턴 판정**

```text
1  2  3
4  5  6
7  8  9

등록 패턴: 1 → 2 → 3 → 6 → 5 → 8
```

마지막 8번 Grid에서 유효 검출 시간이 **누적 1초**에 도달하면 인증을 완료합니다. 순서가 어긋나면 실패를 처리하며, 3회 실패 시 60초 동안 Lockout 상태로 전환하고 Alarm을 표시합니다.

<img width="342" height="203" alt="image" src="https://github.com/user-attachments/assets/aebc1671-ee92-45ba-bd71-3840d23aef95" />

### 2. 인증 경로 Overlay

마커의 이동 경로를 Bresenham 알고리즘으로 선분화하고, 1-bit 경로 메모리에 기록해 VGA 영상에 합성합니다. 좌표 변화 완화, 미세 이동 무시, 큰 위치 변화 배제 조건을 적용해 표시 경로의 흔들림을 줄였습니다.

Grid와 경로는 인증 진행을 확인하는 피드백으로 사용하며, 영상 외곽선과 `단말기`·`홈캠` 라벨을 추가해 두 화면의 역할을 구분했습니다.

### 3. 카메라 입력과 Frame Buffer

SCCB 초기화는 전원 안정화 대기 이후 OV7670 설정 시퀀스를 전송합니다. 영상 캡처에서는 `PCLK`, `HREF`, `VSYNC`를 기준으로 8-bit 입력 두 바이트를 하나의 RGB565 픽셀로 조립합니다.

Frame Buffer는 카메라 클록으로 쓰고 시스템 클록으로 읽는 Dual-clock 구조입니다. 읽기 주소를 표시 좌표에 맞게 변환하고 RGB565를 RGB444로 변환해 VGA 출력으로 전달합니다.

### 4. 영상 필터와 Zoom

| 처리 경로 | 구현 내용 |
|---|---|
| LOCK | 16×16 평균 블러 |
| 색상 필터 그룹 | Normal → Pink → Blue → Orange → Gray |
| 효과 필터 그룹 | Normal → Bright → Brighter → Night |
| 기본 표시 | 320×240 전체 영상을 640×480으로 확대 |
| Zoom 표시 | 160×120 영역 하나를 선택해 640×480으로 확대 |

`gaussian_filter.sv`의 실제 연산은 **동일 가중치의 16×16 Box Blur**입니다. Line Buffer와 Pixel Tap으로 윈도우를 구성하고, 행별 부분합과 전체합을 단계적으로 계산합니다. RGB 데이터와 동기 신호의 지연을 함께 관리해 출력 시점을 맞춥니다.

Zoom은 좌상단·우상단·좌하단·우하단 중 하나를 선택하는 방식이며, 기본 보기 대비 2배 확대합니다. 선택 영역은 다른 Zoom 영역을 선택하거나 Zoom을 해제할 때까지 유지합니다.

<img width="592" height="183" alt="image" src="https://github.com/user-attachments/assets/51951005-4454-4788-9bf3-6a7a8d265e9f" />
<img width="603" height="191" alt="image" src="https://github.com/user-attachments/assets/9b153c4b-831e-4a44-8afb-a7c9a0a50893" />
<img width="485" height="321" alt="image" src="https://github.com/user-attachments/assets/d69b92d2-ceaa-440a-b119-6b4f76121529" />

### 5. UART 상태·이벤트 전달

스위치와 인증 결과는 **상태**, 버튼 입력은 **이벤트**로 처리합니다. Board 1은 인증 상태 변경, 스위치 변경, 버튼 입력이 발생하면 패킷을 구성합니다. Board 2는 수신 완료 시점에 버튼 비트를 1클록 펄스로 변환해 같은 버튼의 반복 입력을 구분합니다.

잠금 상태에서는 사용자 조작 명령을 제한하며, Unlock·Lock 상태 변경 패킷은 별도로 전달합니다.

<details>
<summary><strong>UART 패킷 형식</strong></summary>

Board 1 → Board 2의 1-byte 제어 패킷입니다.

| Bit | 의미 | 종류 |
|---|---|---|
| `[7]` | 예약, `0` | 예약 |
| `[6]` | Unlock | 상태 |
| `[5]` | Up / 필터 순환 | 이벤트 |
| `[4]` | Down / Zoom 영역 선택 | 이벤트 |
| `[3]` | Right / Zoom 영역 선택 | 이벤트 |
| `[2]` | Left / Zoom 영역 선택 | 이벤트 |
| `[1]` | Effect 그룹 | 상태 |
| `[0]` | Zoom Enable | 상태 |

| 패킷 | 의미 |
|---|---|
| `0x00` | Lock |
| `0x40` | Unlock |
| `0x41` | Unlock + Zoom |
| `0x43` | Unlock + Zoom + Effect |
| `0x60` | Unlock + Up 버튼 |

Board 2 → Board 1의 `0x80`은 **별도의 자동 재잠금 알림**입니다. Board 2가 약 10초간 UART 명령을 받지 못하면 블러를 적용하고 이 알림을 전송합니다.

</details>

## 조작 방법

아래 매핑은 최종 Vivado 프로젝트의 RTL과 XDC를 기준으로 합니다.

| 보드 | 입력 | 동작 |
|---|---|---|
| 공통 | `SW15 = 0` | Reset |
| 공통 | `SW15 = 1` | 실행 |
| Board 1 | `SW0 = 1` | 인증 활성화 |
| Board 1 | `SW0 = 0` | 인증 해제 및 잠금 |
| Board 1 | `SW1` | Zoom ON/OFF |
| Board 1 | `SW2 = 0` | 색상 필터 그룹 |
| Board 1 | `SW2 = 1` | 밝기·Night 효과 그룹 |
| Board 1 | `BTNU` | 선택 그룹의 필터 순환 |
| Board 1 | `BTNR` | Zoom 우상단 선택 |
| Board 1 | `BTNL` | Zoom 좌하단 선택 |
| Board 1 | `BTND` | Zoom 우하단 선택 |

Zoom의 초기 선택 영역은 **좌상단**입니다. `SW1`을 껐다 켜면 좌상단으로 돌아갑니다. 필터 및 Zoom 조작은 잠금 해제 후 사용합니다. Lockout 중에는 `SW0`를 내려도 60초 제한이 유지됩니다.

## 검증

영상 데이터와 제어 상태를 서로 다른 검증 환경에서 확인했습니다.

### 영상 필터 Golden Reference 비교

Python Golden Reference와 RTL 출력을 픽셀 단위로 비교했습니다.

| 대상 | Exact Match | 최대 채널 오차 |
|---|---:|---:|
| Pink / Blue / Orange / Gray | 각 100% | 0 |
| Gamma 밝기 설정 2종 / Night | 각 100% | 0 |
| 16×16 Blur | 95.99% | 8 / 15 |

블러 비교 대상은 **76,800픽셀**이며 평균 채널 오차는 **0.0319**입니다. 블러는 보고서의 판정 기준에서 PASS로 기록되었으며, 완전 일치 결과와 구분합니다.

### 카메라·VGA UVM

Camera Driver, Monitor, Predictor, Scoreboard를 구성해 영상 입력과 예상 VGA 출력을 비교했습니다. SCCB는 별도 Monitor와 시나리오로 검증했습니다.

| 검증 영역 | 주요 항목 |
|---|---|
| Camera Capture | RGB565 바이트 조립, 프레임 주소, 정상·랜덤·오류 입력 |
| VGA | 출력 좌표, RGB444 변환, 동기·블랭킹, Gradient 패턴 |
| Zoom | 확대 읽기 주소 매핑 및 픽셀 위치 |
| SCCB | 초기화 시퀀스, NACK·오류 조건 및 복구 |
| Reset | 캡처·VGA·SCCB 동작 중 Reset과 재시작 |
| Camera → VGA | 캡처 데이터가 Frame Buffer를 거쳐 출력되는 경로 |

카메라·VGA DUT 집계에서 **Line, Toggle, FSM, Condition, Branch Coverage 100%**를 기록했습니다. 

### 보드 간 통합 제어

| 시나리오 | 확인 항목 |
|---|---|
| LOCK 상태의 사용자 입력 | 버튼·스위치 조작에 따른 제어 전송 제한 |
| AUTH_SUCCESS | 인증 상태 전이 → UART TX → UART RX → Decode → Board 2 Unlock |
| USER_CONTROL | Zoom·Effect·버튼 조합 패킷과 수신 제어 반영 |
| AUTH_LOCKOUT | 실패 카운트 1→2→3, Lockout, Alarm 및 조작 제한 |
| AUTO_RELOCK | 수신 대기 시간 만료, `0x80` 반환 및 양쪽 재잠금 |

`AUTH_SUCCESS` 시나리오는 **5개 검사 PASS, FAIL 0**, Top 기능 검증은 **정의한 8개 Covergroup 기준 Functional Coverage 100%**를 기록했습니다.

통합 제어 Testbench는 인증 결과를 주입하거나 인증 상태를 설정해 이후의 UART·FSM 연결을 검증합니다. 실제 영상 입력에서 패턴 인식까지의 경로는 이 통합 테스트의 검증 범위와 구분합니다.

<img width="1664" height="757" alt="image" src="https://github.com/user-attachments/assets/cfb53339-5468-4ede-9ff4-9263d6211dd6" />

<img width="1807" height="794" alt="image" src="https://github.com/user-attachments/assets/23feb613-43fc-4394-8690-9d008a500376" />

## 설계 개선과 구현 결과

### 블러 윈도우 및 연산 구조 조정

초기 20×20 블러는 19개 Line Buffer와 400개 Pixel Tap을 사용해 자원 부담이 컸습니다. 윈도우를 16×16으로 줄이고 합산 구조를 조정해 최종 영상 경로에 통합했습니다.

| 항목 | 초기 구조 | 최종 구조 |
|---|---:|---:|
| 윈도우 | 20×20 | 16×16 |
| Line Buffer | 19개 | 15개 |
| Pixel Tap | 400개 | 256개 |
| 평균 계산 | `sum / 400` | `sum / 256` |

`sum / 256`은 8-bit Right Shift와 동등한 상수 연산입니다. 자원 개선은 윈도우 크기와 합산 구조를 함께 조정한 결과로 평가했습니다.

| 자원 | 변경 전 보고값 | 변경 후 보고값 | 감소 폭 |
|---|---:|---:|---:|
| LUT | 63% | 45% | 18%p |
| LUTRAM | 69% | 55% | 14%p |
| FF | 54% | 41% | 13%p |

<img width="1645" height="772" alt="image" src="https://github.com/user-attachments/assets/b72fca56-19ec-4c05-b565-b617da1378d5" />

<img width="1651" height="777" alt="image" src="https://github.com/user-attachments/assets/c00c38c6-e816-40a8-8a0c-d46df29bec07" />

### 추적 안정성과 입력 이벤트 개선

| 문제 | 적용한 설계 |
|---|---|
| 배경의 파란색 잡음으로 Bounding Box가 커짐 | 채널 차이 임계값과 최소 검출 픽셀 수 조정 |
| Grid 경계와 미세 움직임에서 입력이 흔들림 | 3프레임 안정화, 중복 진입 억제, 표시 좌표 완화 |
| 동일 버튼의 반복 입력을 상태 비트만으로 구분하기 어려움 | 스위치 상태와 버튼 이벤트 분리, 수신 시 1클록 펄스 생성 |
| 카메라·제어·VGA의 클록과 처리 시점이 다름 | Dual-clock Frame Buffer, CDC 이벤트 전달, 데이터·동기 신호 지연 정렬 |

### 최종 FPGA 자원 사용량

| 자원 | Board 1 · `system_top` | Board 2 · `OV7670_top` |
|---|---:|---:|
| LUT | 2,121 / 20,800 · **10.20%** | 9,368 / 20,800 · **45.04%** |
| LUT as Memory | 0 / 9,600 · 0% | 5,254 / 9,600 · 54.73% |
| FF | 1,133 / 41,600 · 2.72% | 17,184 / 41,600 · 41.31% |
| BRAM Tile | 39.5 / 50 · 79% | 36.5 / 50 · 73% |
| DSP | 1 / 90 | 0 / 90 |


### 최종 프로젝트 실행

| 보드 | 프로젝트 경로 | Top |
|---|---|---|
| Board 1 | `VGA_Tracking/VGA_Tracking/VGA_Tracking.xpr` | `system_top` |
| Board 2 | `VIDEO_DATAPATH/0902_Video_Datapath/0902_Video_Datapath.xpr` | `OV7670_top` |

1. 최종 프로젝트 패키지를 풀고 Vivado 2020.2에서 각 보드의 `.xpr`을 엽니다.
2. 디바이스가 `xc7a35tcpg236-1`인지 확인하고, 프로젝트에 등록된 RTL·XDC·`ui_labels.mem`을 함께 사용합니다.
3. 각 프로젝트의 XDC에 맞춰 OV7670, VGA, UART를 연결합니다. 카메라 Data 핀 배치는 보드별 XDC를 각각 따릅니다.
4. 제공된 `system_top.bit`, `OV7670_top.bit`을 해당 보드에 프로그램하거나 프로젝트에서 다시 생성합니다.
5. 두 보드의 `SW15`를 `0 → 1`로 전환해 초기화한 뒤, Board 1의 `SW0`로 인증을 시작합니다.

최종 XDC 기준 보드 간 UART 배선은 다음과 같습니다.

| Board 1 | Board 2 |
|---|---|
| JA1 / J1 · RX | JA1 / J1 · TX |
| JA2 / L2 · TX | JA2 / L2 · RX |
| GND | GND |


## 향후 개선

- 조명과 배경 변화에 대응하는 검출 임계값 조정 및 작은 잡음 영역 제거
- 여러 파란색 영역 중 인증 마커를 선택하는 연결 영역 분석
- 사용자 패턴 등록·변경 모드와 인증 시도 정책 개선
- 버튼 연타 이벤트의 개별 보존을 위한 큐 구조 검토
- 카메라 클록 및 I/O 타이밍 제약 보강과 미제약 경로 점검
- 검증 환경의 공통 파일·실행 스크립트·로그를 정리한 재현 패키지 구성

## 프로젝트 문서

설계 과정과 팀별 작업 기록은 [Notion 프로젝트 페이지](https://app.notion.com/p/2nak0/Edge-SoC-Chip-SoC-SoC-3ca6de42f5798023b29ff5e529564ef5)에서 관리했습니다. 






