# 베이스 이미지로 Python 3.8을 사용합니다.
FROM python:3.8

# 작업 디렉터리를 설정합니다.
WORKDIR /app

# 시스템 업데이트 및 필수 패키지 설치
RUN apt-get update && \
    apt-get install -y \
    build-essential \
    default-libmysqlclient-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 애플리케이션의 종속성 파일을 복사합니다.
COPY requirements.txt requirements.txt

# 종속성을 설치합니다.
RUN pip install --no-cache-dir -r requirements.txt

# 애플리케이션의 소스 코드를 복사합니다.
COPY . .

# Flask 애플리케이션을 환경 변수로 설정합니다.
ENV FLASK_APP=app.py

# 컨테이너를 실행할 때 Flask 애플리케이션을 시작합니다.
CMD ["flask", "run", "--host=0.0.0.0", "--port=5000"]
