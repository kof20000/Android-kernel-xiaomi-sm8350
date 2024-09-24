/* SPDX-License-Identifier: GPL-2.0 */
#ifndef _LINUX_PAGE_SIZE_MIGRATION_H
#define _LINUX_PAGE_SIZE_MIGRATION_H

/*
 * Page Size Migration
 *
 * Copyright (c) 2024, Google LLC.
 * Author: Kalesh Singh <kaleshsingh@goole.com>
 *
 * This file contains the APIs for mitigations to ensure
 * app compatibility during the transition from 4kB to 16kB
 * page size in Android.
 */

#include <linux/pgsize_migration_inline.h>
#include <linux/seq_file.h>
#include <linux/mm.h>

#if PAGE_SIZE == SZ_4K && defined(CONFIG_64BIT)
extern void vma_set_pad_pages(struct vm_area_struct *vma,
			      unsigned long nr_pages);

extern unsigned long vma_pad_pages(struct vm_area_struct *vma);

extern void madvise_vma_pad_pages(struct vm_area_struct *vma,
				  unsigned long start, unsigned long end);

extern struct vm_area_struct *get_pad_vma(struct vm_area_struct *vma);

extern struct vm_area_struct *get_data_vma(struct vm_area_struct *vma);

extern void show_map_pad_vma(struct vm_area_struct *vma,
			     struct vm_area_struct *pad,
			     struct seq_file *m, void *func, bool smaps);

extern void split_pad_vma(struct vm_area_struct *vma, struct vm_area_struct *new,
			  unsigned long addr, int new_below);

#else /* PAGE_SIZE != SZ_4K || !defined(CONFIG_64BIT) */
static inline void vma_set_pad_pages(struct vm_area_struct *vma,
				     unsigned long nr_pages)
{
}

static inline unsigned long vma_pad_pages(struct vm_area_struct *vma)
{
	return 0;
}

static inline void madvise_vma_pad_pages(struct vm_area_struct *vma,
					 unsigned long start, unsigned long end)
{
}

static inline struct vm_area_struct *get_pad_vma(struct vm_area_struct *vma)
{
	return NULL;
}

static inline struct vm_area_struct *get_data_vma(struct vm_area_struct *vma)
{
	return vma;
}

static inline void show_map_pad_vma(struct vm_area_struct *vma,
				    struct vm_area_struct *pad,
				    struct seq_file *m, void *func, bool smaps)
{
}

static inline void split_pad_vma(struct vm_area_struct *vma, struct vm_area_struct *new,
				 unsigned long addr, int new_below)
{
}

#endif /* PAGE_SIZE == SZ_4K && defined(CONFIG_64BIT) */

static inline unsigned long vma_data_pages(struct vm_area_struct *vma)
{
	return vma_pages(vma) - vma_pad_pages(vma);
}

/*
 * Merging of padding VMAs is uncommon, as padding is only allowed
 * from the linker context.
 *
 * To simplify the semantics, adjacent VMAs with padding are not
 * allowed to merge.
 */
static inline bool is_mergable_pad_vma(struct vm_area_struct *vma,
				       unsigned long vm_flags)
{
	/* Padding VMAs cannot be merged with other padding or real VMAs */
	return !((vma->vm_flags | vm_flags) & VM_PAD_MASK);
}
#endif /* _LINUX_PAGE_SIZE_MIGRATION_H */
