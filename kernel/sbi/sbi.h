#ifndef SBI_H
#define SBI_H

struct sbiret {
    long error;
    long value;
};

struct sbiret sbi_call(long arg0, long arg1, long arg2, long arg3, long arg4,
                       long arg5, long fid, long eid);

void sbi_putchar(char ch);

#endif
