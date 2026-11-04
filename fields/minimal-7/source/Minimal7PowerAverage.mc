import Toybox.Lang;

// Samples arrive with compute(), approximately once per second.
// During warm-up, average only the samples received so far.
class Minimal7PowerAverage {

    hidden var mSamples as Array<Number>;
    hidden var mIndex as Number = 0;
    hidden var mCount as Number = 0;
    hidden var mSum as Number = 0;

    function initialize(seconds as Number) {
        mSamples = new [seconds];
        for (var i = 0; i < seconds; i += 1) {
            mSamples[i] = 0;
        }
    }

    function push(power as Number) as Number {
        mSum -= mSamples[mIndex];
        mSamples[mIndex] = power;
        mSum += power;
        mIndex = (mIndex + 1) % mSamples.size();
        if (mCount < mSamples.size()) {
            mCount += 1;
        }
        return (mSum + mCount / 2) / mCount;
    }
}
