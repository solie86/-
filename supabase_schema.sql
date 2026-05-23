-- ============================================================
-- 사내 연차 관리 시스템 — Supabase 초기 스키마
-- 사용법:
--   1) Supabase 대시보드 → 좌측 메뉴 "SQL Editor" 클릭
--   2) "New query" 클릭
--   3) 이 파일 전체를 복사해 붙여넣기
--   4) 오른쪽 위 "Run" 클릭
--   5) "Success. No rows returned" 메시지 확인
-- ============================================================

-- ------------------------------------------------------------
-- 1. employees: 직원 마스터
-- ------------------------------------------------------------
create table if not exists employees (
  emp_no          text primary key,                 -- 사번 (로그인 ID 역할)
  name            text not null,
  email           text,
  hire_date       date not null,                    -- 입사일 (연차 자동 계산 기준)
  position        text,                             -- 직급
  department      text,                             -- 부서
  password_hash   text not null,                    -- SHA-256 해시 (평문 절대 저장 안 함)
  role            text not null default 'employee'
                  check (role in ('admin', 'employee')),
  created_at      timestamptz default now()
);

-- ------------------------------------------------------------
-- 2. leave_requests: 연차 신청 내역
-- ------------------------------------------------------------
create table if not exists leave_requests (
  id               uuid primary key default gen_random_uuid(),
  emp_no           text not null references employees(emp_no) on delete cascade,
  requested_at     timestamptz not null default now(),
  start_date       date not null,
  end_date         date not null,
  days             numeric(4,1) not null check (days > 0),  -- 1.0, 0.5 등
  half_day_part    text check (half_day_part in ('AM', 'PM') or half_day_part is null),
  reason           text,
  status           text not null default 'pending'
                   check (status in ('pending', 'approved', 'rejected')),
  approver_emp_no  text references employees(emp_no),
  processed_at     timestamptz
);

-- 자주 쓰는 조회를 위한 인덱스
create index if not exists idx_requests_emp on leave_requests(emp_no);
create index if not exists idx_requests_status on leave_requests(status);
create index if not exists idx_requests_dates on leave_requests(start_date, end_date);

-- ------------------------------------------------------------
-- 3. policy: 연차 정책 (단일 row, id = 1 고정)
-- ------------------------------------------------------------
create table if not exists policy (
  id                integer primary key default 1 check (id = 1),
  monthly_accrual   numeric(3,1) not null default 1,    -- 월별 적립 개수
  year_one_bulk     integer not null default 15,         -- 1년 도달 시 일괄 부여
  allow_past_date   boolean not null default true,       -- 과거 날짜 신청 허용
  updated_at        timestamptz default now()
);

-- 기본 정책 행 한 줄 삽입
insert into policy (id) values (1) on conflict (id) do nothing;

-- ------------------------------------------------------------
-- 4. RLS (Row Level Security) — MVP 단계
--   * 처음엔 anon 키로 자유롭게 읽기/쓰기 허용
--   * 애플리케이션 레벨에서 사번+비번 로그인으로 보호
--   * 추후 Supabase Auth 정식 연동 시 정책을 좁힐 예정
-- ------------------------------------------------------------
alter table employees      enable row level security;
alter table leave_requests enable row level security;
alter table policy         enable row level security;

-- 기존 정책 있으면 제거 후 재생성 (재실행 안전)
drop policy if exists "anon all employees"      on employees;
drop policy if exists "anon all leave_requests" on leave_requests;
drop policy if exists "anon all policy"         on policy;

create policy "anon all employees"
  on employees for all to anon
  using (true) with check (true);

create policy "anon all leave_requests"
  on leave_requests for all to anon
  using (true) with check (true);

create policy "anon all policy"
  on policy for all to anon
  using (true) with check (true);

-- ============================================================
-- 끝. 다음으로 할 일:
--   Supabase 대시보드에서
--     Settings → API 페이지로 이동
--     Project URL 과 anon public key 를 복사해서 Claude에게 알려주세요.
-- ============================================================
