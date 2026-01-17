/*
 * Windows compatibility functions for picoquic/picotls
 * Implements wintimeofday() which is declared in wincompat.h
 *
 * Note: wincompat.h is force-included via /FI compiler flag, which provides
 * the timezone struct definition and the wintimeofday declaration.
 */

#ifdef _WIN32

#include <Winsock2.h>
#include <Windows.h>
#include <stdint.h>

/* timezone struct is already defined in wincompat.h (force-included) */

/*
 * wintimeofday - Windows implementation of gettimeofday
 * 
 * Converts Windows FILETIME to Unix timeval.
 * FILETIME counts 100-nanosecond intervals since January 1, 1601 (UTC).
 * Unix time counts seconds since January 1, 1970 (UTC).
 */
int wintimeofday(struct timeval* tv, struct timezone* tz)
{
    if (tv != NULL) {
        FILETIME ft;
        uint64_t tmp = 0;
        
        /* Number of 100-ns intervals between 1601-01-01 and 1970-01-01 */
        static const uint64_t EPOCH_DIFF = 116444736000000000ULL;
        
        GetSystemTimeAsFileTime(&ft);
        
        /* Convert FILETIME to 64-bit integer */
        tmp |= ((uint64_t)ft.dwHighDateTime << 32);
        tmp |= ft.dwLowDateTime;
        
        /* Convert from Windows epoch to Unix epoch */
        tmp -= EPOCH_DIFF;
        
        /* Convert from 100-ns intervals to seconds and microseconds */
        tv->tv_sec = (long)(tmp / 10000000ULL);
        tv->tv_usec = (long)((tmp % 10000000ULL) / 10);
    }
    
    if (tz != NULL) {
        /* Get timezone information */
        TIME_ZONE_INFORMATION tzinfo;
        GetTimeZoneInformation(&tzinfo);
        tz->tz_minuteswest = tzinfo.Bias;
        tz->tz_dsttime = 0;
    }
    
    return 0;
}

#endif /* _WIN32 */
