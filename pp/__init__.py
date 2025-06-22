from common.constants import gameModes
from pp import rosupp

PP_CALCULATORS = {
    gameModes.STD: rosupp.rosu,      # Use rosu-pp for std
    gameModes.TAIKO: rosupp.rosu,    # Use rosu-pp for taiko
    gameModes.CTB: rosupp.rosu,      # Use rosu-pp for ctb
    gameModes.MANIA: rosupp.rosu,    # Use rosu-pp for mania
}
