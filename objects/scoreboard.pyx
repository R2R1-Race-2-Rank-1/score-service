from objects import score
from common.ripple import userUtils
from constants import rankedStatuses
from common.constants import mods as modsEnum
from objects import glob
from common.log import logUtils as log
import traceback


class scoreboard:
	def __init__(self, username, gameMode, beatmap, setScores = True, country = False, friends = False, mods = -1):
		"""
		Initialize a leaderboard object

		username -- username of who's requesting the scoreboard. None if not known
		gameMode -- requested gameMode
		beatmap -- beatmap objecy relative to this leaderboard
		setScores -- if True, will get personal/top 50 scores automatically. Optional. Default: True
		"""
		try:
			log.info(f"Initializing scoreboard for user {username}, gameMode {gameMode}, beatmap {beatmap.fileMD5}")
			self.scores = []				# list containing all top 50 scores objects. First object is personal best
			self.totalScores = 0
			self.personalBestRank = -1		# our personal best rank, -1 if not found yet
			self.username = username		# username of who's requesting the scoreboard. None if not known
			self.userID = userUtils.getID(self.username)	# username's userID
			self.gameMode = gameMode		# requested gameMode
			self.beatmap = beatmap			# beatmap objecy relative to this leaderboard
			self.country = country
			self.friends = friends
			self.mods = mods
			if setScores:
				self.setScores()
		except Exception as e:
			log.error(f"Error initializing scoreboard: {str(e)}\n{traceback.format_exc()}")
			raise

	@staticmethod
	def buildQuery(params):
		return "{select} {joins} {country} {mods} {friends} {order} {limit}".format(**params)

	def getPersonalBestID(self):
		# Declare all cdef variables at the start
		cdef str select = ""
		cdef str joins = ""
		cdef str country = ""
		cdef str mods = ""
		cdef str friends = ""
		cdef str order = ""
		cdef str limit = ""

		if self.userID == 0:
			log.debug(f"No userID found for username {self.username}")
			return None

		select = "SELECT id FROM scores WHERE userid = %(userid)s AND beatmap_md5 = %(md5)s AND play_mode = %(mode)s AND completed = 3"

		# Mods
		if self.mods > -1:
			mods = "AND mods = %(mods)s"

		# Friends ranking
		if self.friends:
			friends = "AND (scores.userid IN (SELECT user2 FROM users_relationships WHERE user1 = %(userid)s) OR scores.userid = %(userid)s)"

		# Sort and limit at the end
		order = "ORDER BY pp DESC"
		limit = "LIMIT 1"

		# Build query, get params and run query
		query = self.buildQuery(locals())
		params = {"userid": self.userID, "md5": self.beatmap.fileMD5, "mode": self.gameMode, "mods": self.mods}
		
		# Log the full query with parameters
		log.debug(f"Executing personal best query:\nQuery: {query}\nParams: {params}")
		
		id_ = glob.db.fetch(query, params)
		if id_ is None:
			log.debug(f"No personal best found for user {self.username} on beatmap {self.beatmap.fileMD5}")
			return None
		log.debug(f"Found personal best ID {id_['id']} for user {self.username} on beatmap {self.beatmap.fileMD5}")
		return id_["id"]

	def setScores(self):
		"""
		Set scores list
		"""
		# Declare all cdef variables at the start
		cdef str select = ""
		cdef str joins = ""
		cdef str country = ""
		cdef str mods = ""
		cdef str friends = ""
		cdef str order = ""
		cdef str limit = ""
		cdef int c = 1
		cdef dict topScore

		try:
			log.info(f"Setting scores for beatmap {self.beatmap.fileMD5}, gameMode {self.gameMode}")
			# Reset score list
			self.scores = []
			self.scores.append(-1)

			# Make sure the beatmap is ranked
			if self.beatmap.rankedStatus < rankedStatuses.RANKED:
				log.warning(f"Beatmap {self.beatmap.fileMD5} is not ranked (status: {self.beatmap.rankedStatus})")
				return

			# Find personal best score
			personalBestScoreID = self.getPersonalBestID()

			# Output our personal best if found
			if personalBestScoreID is not None:
				s = score.score(personalBestScoreID)
				self.scores[0] = s
			else:
				# No personal best
				self.scores[0] = -1

			# Get top 50 scores
			select = "SELECT *"
			joins = "FROM scores STRAIGHT_JOIN users ON scores.userid = users.id STRAIGHT_JOIN users_stats ON users.id = users_stats.id WHERE scores.beatmap_md5 = %(beatmap_md5)s AND scores.play_mode = %(play_mode)s AND scores.completed = 3 AND (users.privileges & 1 > 0 OR users.id = %(userid)s)"

			# Country ranking
			if self.country:
				country = "AND users_stats.country = (SELECT country FROM users_stats WHERE id = %(userid)s LIMIT 1)"
			else:
				country = ""

			# Mods ranking (ignore auto, since we use it for pp sorting)
			if self.mods > -1 and self.mods & modsEnum.AUTOPLAY == 0:
				mods = "AND scores.mods = %(mods)s"
			else:
				mods = ""

			# Friends ranking
			if self.friends:
				friends = "AND (scores.userid IN (SELECT user2 FROM users_relationships WHERE user1 = %(userid)s) OR scores.userid = %(userid)s)"
			else:
				friends = ""

			# Sort and limit at the end
			if self.mods <= -1 or self.mods & modsEnum.AUTOPLAY == 0:
				# Order by score if we aren't filtering by mods or autoplay mod is disabled
				order = "ORDER BY score DESC"
			elif self.mods & modsEnum.AUTOPLAY > 0:
				# Otherwise, filter by pp
				order = "ORDER BY pp DESC"
			limit = "LIMIT 50"

			# Build query, get params and run query
			query = self.buildQuery(locals())
			params = {"beatmap_md5": self.beatmap.fileMD5, "play_mode": self.gameMode, "userid": self.userID, "mods": self.mods}
			
			# Log the full query with parameters
			log.debug(f"Executing top scores query:\nQuery: {query}\nParams: {params}")
			
			topScores = glob.db.fetchAll(query, params)

			if topScores is not None:
				log.info(f"Found {len(topScores)} scores for beatmap {self.beatmap.fileMD5}")
				for topScore in topScores:
					# Create score object
					s = score.score(topScore["id"], setData=False)

					# Set data and rank from topScores's row
					s.setDataFromDict(topScore)
					s.rank = c

					# Check if this top 50 score is our personal best
					if s.playerName == self.username:
						self.personalBestRank = c
						log.debug(f"Found personal best rank {c} for user {self.username}")

					# Add this score to scores list and increment rank
					self.scores.append(s)
					c+=1
			else:
				log.warning(f"No scores found for beatmap {self.beatmap.fileMD5}")
		except Exception as e:
			log.error(f"Error in setScores: {str(e)}\n{traceback.format_exc()}")
			raise

	def setPersonalBestRank(self):
		"""
		Set personal best rank ONLY
		Ikr, that query is HUGE but xd
		"""
		# Declare all cdef variables at the start
		cdef str query = ""

		try:
			log.debug(f"Setting personal best rank for user {self.username} on beatmap {self.beatmap.fileMD5}")
			# Before running the HUGE query, make sure we have a score on that map
			query = "SELECT id FROM scores WHERE beatmap_md5 = %(md5)s AND userid = %(userid)s AND play_mode = %(mode)s AND completed = 3"
			# Mods
			if self.mods > -1:
				query += " AND scores.mods = %(mods)s"
			# Friends ranking
			if self.friends:
				query += " AND (scores.userid IN (SELECT user2 FROM users_relationships WHERE user1 = %(userid)s) OR scores.userid = %(userid)s)"
			# Sort and limit at the end
			query += " LIMIT 1"
			
			params = {"md5": self.beatmap.fileMD5, "userid": self.userID, "mode": self.gameMode, "mods": self.mods}
			log.debug(f"Executing initial score check query:\nQuery: {query}\nParams: {params}")
			
			hasScore = glob.db.fetch(query, params)
			if hasScore is None:
				log.debug(f"No score found for user {self.username} on beatmap {self.beatmap.fileMD5}")
				return

			# We have a score, run the huge query
			# Base query
			query = "SELECT COUNT(*) AS `rank` FROM scores STRAIGHT_JOIN users ON scores.userid = users.id STRAIGHT_JOIN users_stats ON users.id = users_stats.id WHERE scores.score >= (SELECT score FROM scores WHERE beatmap_md5 = %(md5)s AND play_mode = %(mode)s AND completed = 3 AND userid = %(userid)s LIMIT 1) AND scores.beatmap_md5 = %(md5)s AND scores.play_mode = %(mode)s AND scores.completed = 3 AND users.privileges & 1 > 0"
			# Country
			if self.country:
				query += " AND users_stats.country = (SELECT country FROM users_stats WHERE id = %(userid)s LIMIT 1)"
			# Mods
			if self.mods > -1:
				query += " AND scores.mods = %(mods)s"
			# Friends
			if self.friends:
				query += " AND (scores.userid IN (SELECT user2 FROM users_relationships WHERE user1 = %(userid)s) OR scores.userid = %(userid)s)"
			# Sort and limit at the end
			query += " ORDER BY pp DESC LIMIT 1"
			
			log.debug(f"Executing rank calculation query:\nQuery: {query}\nParams: {params}")
			
			result = glob.db.fetch(query, params)
			if result is not None:
				self.personalBestRank = result["rank"]
				log.info(f"Set personal best rank to {self.personalBestRank} for user {self.username} on beatmap {self.beatmap.fileMD5}")
			else:
				log.warning(f"Failed to get personal best rank for user {self.username} on beatmap {self.beatmap.fileMD5}")
		except Exception as e:
			log.error(f"Error in setPersonalBestRank: {str(e)}\n{traceback.format_exc()}")
			raise

	def getScoresData(self):
		"""
		Return scores data for getscores

		return -- score data in getscores format
		"""
		try:
			log.debug(f"Getting scores data for beatmap {self.beatmap.fileMD5}")
			data = ""

			# Output personal best
			if self.scores[0] == -1:
				# We don't have a personal best score
				log.debug(f"No personal best score found for user {self.username} on beatmap {self.beatmap.fileMD5}")
				data += "\n"
			else:
				# Set personal best score rank
				self.setPersonalBestRank()	# sets self.personalBestRank with the huge query
				self.scores[0].rank = self.personalBestRank
				data += self.scores[0].getData()

			# Output top 50 scores
			for i in self.scores[1:]:
				data += i.getData(pp=True)

			return data
		except Exception as e:
			log.error(f"Error in getScoresData: {str(e)}\n{traceback.format_exc()}")
			raise
