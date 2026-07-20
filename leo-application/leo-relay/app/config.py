from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    leo_relay_token: str = "change-me-demo-token"
    host: str = "0.0.0.0"
    port: int = 8080
    # Set MOCK_MAP=true to serve a synthetic map when no robot is online.
    mock_map: bool = False


settings = Settings()
