# OV7670 영상처리 기반 Fruit Ninja 게임 구현

## 프로젝트 개요

**OV7670 카메라 + VGA 출력 + FPGA**를 이용해

→ 화면 속 빨간색 물체(손/막대)를 인식해 과일을 자르는 **Fruit Ninja 게임 구현**

## 프로젝트 목적

- 카메라 영상 처리 기반 객체 인식 구현
- HSV 기반 Red Filter + Blob Detection
- FPGA 상의 실시간 물리 엔진
- 스프라이트 렌더링을 통한 게임 UI 구성
- 완전 하드웨어 기반 과일 생성·충돌·점수 시스템 구축

---

## 🧰 개발 환경

### ● Language

- **SystemVerilog**

### ● Board

- **FPGA + OV7670 Camera + VGA Port**

### ● Tools

- Vivado
- Python (포물선 궤적 시뮬레이션 및 Golden Reference)

---

## 👥 팀원 역할

| 팀원 | 담당 |
| --- | --- |
| Team Member | 게임 UI 구현, 스프라이트 렌더링, Score/Life UI 처리 |
| Team Member | 물리엔진, 과일·커서 렌더링, Gaussian Filter |
| **석경현** | Line Buffer, 3×3 Red Filter, Timing Control |
| -Team Member | 카메라 초기화(SCCB), Golden Reference, 시스템 설계 |

---

# 2. 🖥 VGA Controller

## SCCB(Camera Control)

- FPGA가 **마스터**, OV7670이 **슬레이브**
- 프로토콜:
    
    `ID 전송 → 레지스터 주소 → 데이터 값`
    
- 각 바이트 전송 후 ACK 확인
- 내부 ROM의 **75개 초기 설정값**을 FSM이 순차적으로 전송
- SIO_D 라인은 **IOBUF** 사용 (송신·수신 전환)

---

## OV7670 영상 수신 → Pipeline 처리 흐름

### 1) **RGB444 입력 수신**

카메라로부터 픽셀 데이터를 수집

### 2) **3×3 Line Buffer 구성**

- 9픽셀 윈도우 생성
- 공간 필터링 기반 색 안정화

### 3) **HSV 변환 → Red 색 검출**

- Hue 중심 Thresholding
- SAT_MIN ~ SAT_MAX
- VAL_MIN ~ VAL_MAX 조건 모두 만족해야 red_detected=1

### 4) **Morphological Filter**

- 작은 노이즈 제거
- 끊긴 영역 연결
- blob 내부 구멍 메꿈

### 5) **Blob Detection**

- red blob의 최소 x,y 위치 계산
- 가장 큰 blob만 유효 처리 (largest_count > 20)

### 6) **Cursor 중심점 계산**

- Blob 중심 → 게임 커서 좌표로 사용

---

# 3. 🎮 Game Controller

## 📌 게임 상태 흐름

`TITLE → PLAYING → GAMEOVER → TITLE`

- TITLE: 커서가 Start 버튼 위에서 3초 유지 → 시작
- PLAYING: 목숨이 0이 되는 순간 GAMEOVER
- GAMEOVER: Menu 버튼에 3초 유지 → TITLE 복귀

---

## 🎲 LFSR 기반 랜덤성

- 15·13·12·10 비트를 XOR하여 LSB에 삽입
- 1bit 좌측 Shift
- 과일마다 **시작 위치·속도 랜덤 생성**

---

## 🍎 Fruit Spawner (포물선)

### ● 포물선 초기값 수식

- y = v0*t − 0.5*g*t² 기반
- VGA 640×480 내부에 항상 등장하도록 파라미터 조정
- Python으로 궤적 시뮬레이션하여 시각적으로 검증

### ● 위치 증가량 (Δx, Δy)

- 매 프레임마다 계산
- 속도/방향/중력에 따른 자연스러운 움직임 구현

---

## 🍉 Fruit Render (스프라이트 렌더링)

- 현재 VGA pixel이 특정 과일의 80×80 Hitbox 안인지 검사
- Hitbox → 16×16 Sprite 좌표로 downscale
- ROM에서 픽셀 색상 읽어 RGB 출력

```
rel_x = x_pixel - fruit_x + HALF_SIZE
# 과일 크기: -40 ~ +40 범위
```

---

## ⚔️ Collision Detector

- Cursor와 fruit hitbox overlap 시 충돌
- 폭탄(3’d6)과 충돌 → 목숨 감소
- 과일과 충돌 → 점수 증가

---

## ❤️ Score & Life Manager

- 과일 타입별 점수 부여
- 폭탄 제외 과일을 **놓치면** life –1
- 이미 처리된 과일은 (already_scored / already_missed) 플래그로 중복 방지

---

## 🖼 UI Render

- **TITLE**: 타이틀 이미지 + Start 버튼
- **PLAYING**:
    - Score Box
    - 숫자 폰트
    - Life 하트
- **GAMEOVER**:
    - GAME OVER 텍스트
    - 최종 점수
    - Menu 버튼

---

# 4. 🛠 Trouble Shooting

## ⚠️ 목숨이 2씩 감소하는 버그

**원인:** 동일 과일이 여러 프레임에서 중복 처리됨

**해결:**

- already_missed / already_scored 플래그 사용
- 한 번 처리된 과일은 다음 프레임에서 무시

---

## ⚠️ 상하 반전 모드에서 커서 반대로 움직임

**원인:** 좌표계 반전 미적용

**해결:**

`blob_y_flip = 479 - blob_y`

---

## ⚠️ 빨간색 검출 범위가 넓어 노이즈에 반응

**해결:**

- 가장 큰 blob만 선택(largest_count > 20 조건)
- HSV에서 Saturation, Value 조건 추가
    
    → 채도·명도가 낮은 빨간색은 모두 제거
    

**Before / After 비교:**

- BEFORE: 작은 빨간색에도 커서가 튐
- AFTER: 안정적 추적

---

# 5. 🏁 Conclusion

### 🟦 석경현

Line Buffer, 3×3 Filter 설계 과정에서

타이밍 제어 및 동기화의 중요성을 배움.

### 🟩 Team Member

그래픽 UI가 중첩되지 않도록 조율하는 것의 복잡함 체감.

물리 기반 움직임 튜닝의 중요성을 깨달음.

### 🟧 Team Member

포물선 궤적을 VGA 내부에 자연스럽게 넣기 위해

Python으로 Golden Reference를 작성하여 문제 해결.

하드웨어 구현 전 검증의 중요성 체득.

### 🟪 Team Member

Cursor tracking의 부드러운 움직임 구현 과정에서

영상 신호의 프레임·노이즈·색상 변화 특성을 실제로 이해함.

필터 설계 능력 향상.
