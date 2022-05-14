def getRatio(numerator, denominator) -> int:
    _numerator = numerator * (10 ** (18 + 1))
    _quotient = ((_numerator // denominator) + 19) // 10
    return _quotient

def safeCastToInt96(_value) -> int:
    if (_value > (2 ** 96) - 1):
        return 0
    _result = int(_value)
    return _result

flowRate = int(0.00003858 * (10 ** 18))
token1 = 100 * (10 ** 18)
token2 = 99 * (10 ** 18)

ratio = getRatio(token2, token1)
outRate1 = (ratio * flowRate) // 10 ** 18
outRate2 = (2 * flowRate) - outRate1

print("FlowRate:", flowRate)
print("ratio:", ratio)
print("outRate1:", outRate1)
print("outRate2:", outRate2)


# Token 1 - 100
# Token 2 - 99

RATIO = 0.99
Flow  = 0.00003858

step0 = RATIO + (Flow *(1-RATIO))
step1 = Flow * (1 + (1-RATIO))
step2 = Flow * (2 - RATIO)



print(step1, step2)
