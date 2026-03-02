-- =========================================
-- 1) META DE RECURSOS DEL SOURCE (ETag/Last-Modified)
-- =========================================
CREATE TABLE dbo.SourceResources (
  ResourceKey     NVARCHAR(300) NOT NULL PRIMARY KEY, -- ej: es/quarterlies/2026-01/index.json
  Url             NVARCHAR(700) NOT NULL,
  ETag            NVARCHAR(120) NULL,
  LastModified    NVARCHAR(120) NULL,
  ContentHash     VARBINARY(32) NULL,
  UpdatedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

-- =========================================
-- 2) CONTENIDO CACHEADO (Quarterly/Lesson/DayRead/Media)
-- =========================================
CREATE TABLE dbo.Quarterlies (
  Lang          NVARCHAR(10) NOT NULL,
  QuarterlyId   NVARCHAR(30) NOT NULL, -- ej: 2026-01
  Title         NVARCHAR(250) NULL,
  CoverUrl      NVARCHAR(600) NULL,
  StartDate     DATE NULL,
  EndDate       DATE NULL,
  RawJson       NVARCHAR(MAX) NULL,
  UpdatedAt     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_Quarterlies PRIMARY KEY (Lang, QuarterlyId)
);

CREATE TABLE dbo.Lessons (
  Lang        NVARCHAR(10) NOT NULL,
  QuarterlyId NVARCHAR(30) NOT NULL,
  LessonId    NVARCHAR(10) NOT NULL,  -- "01".."13"
  Title       NVARCHAR(250) NULL,
  StartDate   DATE NULL,
  EndDate     DATE NULL,
  RawJson     NVARCHAR(MAX) NULL,
  UpdatedAt   DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_Lessons PRIMARY KEY (Lang, QuarterlyId, LessonId)
);

CREATE TABLE dbo.DayReads (
  Lang        NVARCHAR(10) NOT NULL,
  QuarterlyId NVARCHAR(30) NOT NULL,
  LessonId    NVARCHAR(10) NOT NULL,
  DayId       NVARCHAR(10) NOT NULL,  -- "01".."07" (o los que existan)
  DayDate     DATE NULL,
  Title       NVARCHAR(250) NULL,
  ReadJson    NVARCHAR(MAX) NOT NULL, -- contenido de read/index.json
  UpdatedAt   DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_DayReads PRIMARY KEY (Lang, QuarterlyId, LessonId, DayId)
);

CREATE TABLE dbo.QuarterlyMedia (
  Lang        NVARCHAR(10) NOT NULL,
  QuarterlyId NVARCHAR(30) NOT NULL,
  MediaType   NVARCHAR(10) NOT NULL, -- 'audio' | 'video'
  RawJson     NVARCHAR(MAX) NOT NULL,
  UpdatedAt   DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_QuarterlyMedia PRIMARY KEY (Lang, QuarterlyId, MediaType)
);

CREATE INDEX IX_DayReads_UpdatedAt ON dbo.DayReads(UpdatedAt);
CREATE INDEX IX_Lessons_Quarterly ON dbo.Lessons(Lang, QuarterlyId);
