# Supabase 마이그레이션

이 폴더는 실제 Supabase 프로젝트(`apwjwaryrlpqmdabilvu`, agy-vibe-coding)에 이미 적용된 스키마를 Supabase CLI 규칙대로 정리한 것입니다.

## 현재 상태
- 마이그레이션 파일은 여기 있지만, GitHub 저장소와 Supabase 프로젝트는 아직 자동연동(GitHub Integration)이 안 돼있음
- 지금까지 스키마 변경은 Claude가 Supabase API로 직접 적용 → 이 폴더에 사후 기록하는 방식

## GitHub 자동연동 켜는 법 (사람이 직접, 2~3클릭)
자동연동(push하면 자동으로 마이그레이션 적용)은 GitHub App 설치가 필요해서 API로 대신 할 수 없습니다. 대표님이 직접:

1. https://supabase.com/dashboard/project/apwjwaryrlpqmdabilvu/settings/integrations 접속
2. "GitHub" 통합 → Connect to GitHub
3. 저장소 선택: `joseki-korea/labsync-research-prototype`
4. 브랜치=`main`, 마이그레이션 경로=이 폴더(`supabase/migrations`) 확인

연동하면 이후 스키마 변경은 이 폴더에 파일 추가 + push만 하면 자동 적용됩니다.
