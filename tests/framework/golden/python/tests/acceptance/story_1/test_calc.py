"""Acceptance contract fixture (python convention): tests/acceptance/story_<nr>/."""
from src.calc import add


def test_add_ac1():
    # AC-1: adds two positive integers
    assert add(2, 3) == 5


def test_add_ac2():
    # AC-2: adds with zero identity
    assert add(0, 7) == 7
