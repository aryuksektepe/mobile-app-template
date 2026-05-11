---
description: skill-extractor'ı manuel olarak çalıştır — belirli bir CHRONICLED faz için reusable skill'leri kristalize et.
allowed-tools: Task, Read, Write, Edit
---

# /extract-skill

Manuel olarak skill-extractor'ı tetikle. Genelde orchestrator otomatik tetikler, ama:
- Geçmiş bir CHRONICLED fazdan unutulmuş bir pattern'i extract etmek istiyorsan
- Mevcut bir skill'i refresh etmek istiyorsan (`last_verified` güncelleme)

## Talimat

User input ($ARGUMENTS) faz id'sini içeriyor (opsiyonel — boşsa en son CHRONICLED phase).

`skill-extractor` Task'ını başlat:

```
subagent_type: skill-extractor
description: Extract skills from phase {id or latest CHRONICLED}
prompt: User invoked /extract-skill manually. Target phase: {id from $ARGUMENTS or latest CHRONICLED}. Read phase frontmatter skills_to_extract array, apply §3 workflow, create skill directories, update INDEX.md.
```

User input: $ARGUMENTS
