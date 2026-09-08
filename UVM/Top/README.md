# VGA_PROJECT_FIN 인증 테스트 실행 안내

이 문서는 `AUTH_SUCCESS`와 `AUTH_LOCKOUT` UVM 테스트의 실행 방법을 설명한다.
시뮬레이션은 Synopsys VCS와 UVM 1.2를 사용하며, 파형 확인에는 Verdi, 커버리지 병합에는 URG가 필요하다.

모든 명령은 프로젝트 최상위 디렉터리 `VGA_PROJECT_FIN`에서 실행한다.

## 테스트 실행

```bash
# 인증 성공 테스트
make auth-success

# 인증 잠금 테스트
make auth-lockout

# 두 테스트를 병렬 실행
make auth
```

컴파일만 수행하려면 테스트별 `build` 타깃을 사용한다.

```bash
make -C AUTH_SUCCESS/SIM build
make -C AUTH_LOCKOUT/SIM build
```

## 테스트 시나리오

| 테스트 | 시나리오와 확인 항목 |
|---|---|
| `AUTH_SUCCESS` | 인증 성공을 주입하고 잠금 해제, UART 상태·버튼·스위치 전달, `0x80` 원격 재잠금을 검사한다. |
| `AUTH_LOCKOUT` | 인증 실패를 3회 주입하고 실패 횟수, 경보 발생, 잠금 중 제어 차단을 검사한다. |

두 테스트 모두 각 보드에서 OV7670 설정값 67개를 기준 데이터 및 SCCB 버스 전송과 비교한다. 인증 결과와 타임아웃은 빠른 제어·UART 검증을 위해 테스트벤치에서 주입한다.

## 결과 확인

테스트별 결과는 다음 디렉터리에 생성된다.

```text
AUTH_SUCCESS/SIM/sim/
AUTH_LOCKOUT/SIM/sim/
```

각 결과 디렉터리의 주요 파일은 다음과 같다.

```text
compile.log       VCS 컴파일 로그
sim.log           UVM 실행 로그
simv              시뮬레이션 실행 파일
wave.fsdb         파형 파일
coverage.vdb/     코드 및 functional coverage 데이터
```

성공한 테스트는 `sim.log`의 최종 UVM 요약에서 `UVM_ERROR`와 `UVM_FATAL`이 모두 0이어야 한다. 인증 scoreboard의 `AUTH Verification Summary`에서도 모든 항목이 `PASS`인지 확인한다.

기존 `sim/`에 실행 로그가 있으면 다음 실행 전에 `sim_MMDD_HH_MM_SS/` 형태로 보관된다.

## 파형과 커버리지

테스트별 파형 또는 커버리지를 Verdi에서 연다. 인증용 Makefile에는 별도의 `debug`와 `coverage` 타깃이 없으므로 결과 경로를 직접 지정한다.

```bash
verdi -dbdir AUTH_SUCCESS/SIM/sim/simv.daidir \
  -ssf AUTH_SUCCESS/SIM/sim/wave.fsdb &

verdi -cov -covdir AUTH_SUCCESS/SIM/sim/coverage.vdb \
  -dbdir AUTH_SUCCESS/SIM/sim/simv.daidir \
  -ssf AUTH_SUCCESS/SIM/sim/wave.fsdb &

verdi -dbdir AUTH_LOCKOUT/SIM/sim/simv.daidir \
  -ssf AUTH_LOCKOUT/SIM/sim/wave.fsdb &

verdi -cov -covdir AUTH_LOCKOUT/SIM/sim/coverage.vdb \
  -dbdir AUTH_LOCKOUT/SIM/sim/simv.daidir \
  -ssf AUTH_LOCKOUT/SIM/sim/wave.fsdb &
```

두 인증 테스트를 실행한 뒤 커버리지를 병합하려면 다음 명령을 사용한다. 실행과 병합 순서를 유지하기 위해 `-j` 옵션은 추가하지 않는다.

```bash
make auth-all
```

병합 결과는 다음 위치에 생성된다.

```text
AUTH_MERGED_COVERAGE/merged.vdb/
AUTH_MERGED_COVERAGE/report/dashboard.html
```

## 결과 정리

현재 테스트 결과를 삭제하려면 해당 테스트의 `clean` 타깃을 사용한다.

```bash
make -C AUTH_SUCCESS/SIM clean
make -C AUTH_LOCKOUT/SIM clean
```

각 명령은 해당 테스트의 `SIM/sim/`만 삭제하며, 시간 이름으로 보관된 이전 결과 디렉터리는 유지한다.
