import os
import configparser

from decouple import config, Csv


class Config:
	def __init__(self):
		self._config = {
			"DEBUG": config("DEBUG", default="1", cast=bool),

			"DB_HOST": config("DB_HOSTT", default="db"),
			"DB_PORT": config("DB_PORTT", default="3306", cast=int),
			"DB_USERNAME": config("DB_USERNAME", default="root"),
			"DB_PASSWORD": config("DB_PASSWORD", default=os.environ.get("DB_PASS", "")),
			"DB_NAME": config("DB_NAME", default="ripple"),
			"DB_WORKERS": config("DB_WORKERS", default="8", cast=int),

			"REDIS_HOST": config("REDIS_HOSTT", default="redis.default.svc.cluster.local"),
			"REDIS_PORT": config("REDIS_PORTT", default="6379", cast=int),
			"REDIS_DATABASE": config("REDIS_DATABASE", default="0", cast=int),
			"REDIS_PASSWORD": config("REDIS_PASSWORD", default=None),

			"HTTP_HOST": config("HTTP_HOST", default="0.0.0.0"),
			"HTTP_PORT": config("HTTP_PORT", default="80", cast=int),

			"BEATMAP_CACHE_EXPIRE": config("BEATMAP_CACHE_EXPIRE", default="86400", cast=int),

			"SERVER_URL": config("SERVER_URL", default="http://scores-service.default.svc.cluster.local"),
			"BANCHO_URL": config("BANCHO_URL", default="http://bancho-service-api.default.svc.cluster.local"),
			"BANCHO_API_KEY": config("BANCHO_API_KEY", default=""),

			"THREADS": config("THREADS", default="4", cast=int),
			"REPLAYS_FOLDERS": config("REPLAYS_FOLDERS", default="/data/.data/replays", cast=Csv(str)),
			"BEATMAPS_FOLDER": config("BEATMAPS_FOLDER", default="/data/.data/beatmaps", cast=str),
			"SCREENSHOTS_FOLDER": config("SCREENSHOTS_FOLDER", default="/data/.data/screenshots", cast=str),

			"SENTRY_ENABLED": config("SENTRY_ENABLED", default="0", cast=bool),
			"SENTRY_DSN": config("SENTRY_DSN", default=""),

			"DATADOG_API_KEY": config("DATADOG_API_KEY", default=""),
			"DATADOG_APP_KEY": config("DATADOG_APP_KEY", default=""),

			"OSU_API_ENABLE": config("OSU_API_ENABLE", default="1", cast=bool),
			"OSU_API_URL": config("OSU_API_URL", default="https://osu.ppy.sh"),
			"OSU_API_KEY": config("OSU_API_KEY", default=os.environ.get("OSU_API_KEY", "")),

			"CHEESEGULL_API_URL": config("CHEESEGULL_API_URL", default="http://beatmaps.akatsuki.pw/api"),

			"SCHIAVO_URL": config("SCHIAVO_URL", default=""),
			"DISCORD_SECRET_WEB_HOOK": config("DISCORD_SECRET_WEB_HOOK", default=""),

			"CONO_ENABLE": config("CONO_ENABLE", default="0", cast=bool),
		}

	@property
	def sentry_enabled(self):
		return bool(self["SENTRY_DSN"])

	@property
	def datadog_enabled(self):
		return bool(self["DATADOG_API_KEY"]) and bool(self["DATADOG_APP_KEY"])

	@property
	def schiavo_enabled(self):
		return bool(self["SCHIAVO_URL"])

	def __getitem__(self, item):
		return self._config[item]

	def __setitem__(self, key, value):
		self._config[key] = value
