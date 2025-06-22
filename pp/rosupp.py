"""
rosu-pp-py interface for ripple 2 / LETS
Unified calculator for all game modes
"""
import rosu_pp_py as pp

from common.constants import gameModes
from common.log import logUtils as log
from common.ripple import scoreUtils
from constants import exceptions
from helpers import mapsHelper

# constants
MODULE_NAME = "rosupp"

class RosuError(Exception):
    def __init__(self, error):
        self.error = error

class rosu:
    """
    Rosu-pp calculator for all game modes
    """
    
    def __init__(self, __beatmap, __score = None, acc = 0, mods = 0, tillerino = False):
        """
        Set rosu-pp params.

        __beatmap -- beatmap object
        __score -- score object
        acc -- manual acc. Used in tillerino-like bot. You don't need this if you pass __score object
        mods -- manual mods. Used in tillerino-like bot. You don't need this if you pass __score object
        tillerino -- If True, self.pp will be a list with pp values for 100%, 99%, 98% and 95% acc. Optional.
        """
        # Default values
        self.pp = None
        self.score = None
        self.acc = 0
        self.mods = 0
        self.combo = -1  # FC
        self.misses = 0
        self.stars = 0
        self.tillerino = tillerino

        # Beatmap object
        self.beatmap = __beatmap

        # If passed, set everything from score object
        if __score is not None:
            self.score = __score
            self.acc = self.score.accuracy * 100
            self.mods = self.score.mods
            self.combo = self.score.maxCombo
            self.misses = self.score.cMiss
            self.gameMode = self.score.gameMode
        else:
            # Otherwise, set acc and mods from params (tillerino)
            self.acc = acc
            self.mods = mods
            # Determine game mode from beatmap stars
            if self.beatmap.starsStd > 0:
                self.gameMode = gameModes.STD
            elif self.beatmap.starsTaiko > 0:
                self.gameMode = gameModes.TAIKO
            elif self.beatmap.starsCtb > 0:
                self.gameMode = gameModes.CTB
            elif self.beatmap.starsMania > 0:
                self.gameMode = gameModes.MANIA
            else:
                self.gameMode = gameModes.STD  # Default fallback

        # Calculate pp
        log.debug("rosu ~> Initialized rosu-pp diffcalc")
        self.calculatePP()

    def calculatePP(self):
        """
        Calculate total pp value using rosu-pp-py
        """
        self.pp = None

        try:            # Prepare beatmap on disk
            mapFile = mapsHelper.cachedMapPath(self.beatmap.beatmapID)
            log.debug(f"rosu ~> Map file: {mapFile}")
            mapsHelper.cacheMap(mapFile, self.beatmap)

            # Load with rosu-pp-py
            bmap = pp.Beatmap(path=mapFile)

            # Choose mode based on game mode
            if self.gameMode == gameModes.STD:
                mode = pp.GameMode.Osu
            elif self.gameMode == gameModes.TAIKO:
                mode = pp.GameMode.Taiko
            elif self.gameMode == gameModes.CTB:
                mode = pp.GameMode.Catch
            elif self.gameMode == gameModes.MANIA:
                mode = pp.GameMode.Mania
            else:
                raise exceptions.unsupportedGameModeException()
            
            # Convert beatmap to the target mode if needed
            bmap.convert(mode)

            # Use only mods supported by rosu-pp (should be more than oppai)
            modsFixed = self.mods & 8191  # More permissive than oppai's 5983            # Set up calculation parameters
            combo = self.combo if self.combo >= 0 else None
            misses = self.misses if self.misses > 0 else None

            if not self.tillerino:
                # Single calculation
                acc_frac = self.acc / 100.0 if self.acc > 0 else None
                
                # Build performance calculator
                calc = pp.Performance(
                    mods=modsFixed,
                    combo=combo,
                    misses=misses,
                    accuracy=acc_frac
                )
                
                result = calc.calculate(bmap)
                self.pp = result.pp
                self.stars = result.difficulty.stars                # Sanity checks for broken maps
                if self._isBrokenMap(result):
                    self.pp = 0

            else:
                # Tillerino mode - calculate for multiple accuracies
                pp_list = []
                for acc in (1.0, 0.99, 0.98, 0.95):
                    calc = pp.Performance(
                        mods=modsFixed,
                        combo=combo,
                        misses=misses,
                        accuracy=acc
                    )
                    
                    result = calc.calculate(bmap)
                    
                    if self._isBrokenMap(result):
                        pp_list = [0, 0, 0, 0]
                        break
                    pp_list.append(result.pp)
                
                self.pp = pp_list
                # Set stars from the first calculation
                if pp_list and pp_list[0] > 0:
                    calc = pp.Performance(mods=modsFixed)
                    result = calc.calculate(bmap)
                    self.stars = result.difficulty.stars

            log.debug(f"rosu ~> Calculated PP: {self.pp}, stars: {self.stars}")

        except Exception as e:
            log.error(f"rosu ~> Error calculating PP: {e}")
            self.pp = 0
            self.stars = 0        finally:
            log.debug(f"rosu ~> Shutting down, pp = {self.pp}")

    def _isBrokenMap(self, result):
        """
        Check if the calculated result indicates a broken map
        """
        
        # Check for extremely high star rating
        if result.difficulty.stars > 20:
            return True
        
        # Taiko-specific checks (legacy from oppai code)
        if (self.gameMode == gameModes.TAIKO and 
            hasattr(self.beatmap, 'starsStd') and 
            self.beatmap.starsStd > 0 and 
            result.pp > 800):
            return True
        
        return False