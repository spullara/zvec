#ifndef ZVEC_C_H
#define ZVEC_C_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// --- Status ---
typedef enum {
    ZVEC_STATUS_OK = 0,
    ZVEC_STATUS_NOT_FOUND,
    ZVEC_STATUS_ALREADY_EXISTS,
    ZVEC_STATUS_INVALID_ARGUMENT,
    ZVEC_STATUS_PERMISSION_DENIED,
    ZVEC_STATUS_FAILED_PRECONDITION,
    ZVEC_STATUS_RESOURCE_EXHAUSTED,
    ZVEC_STATUS_UNAVAILABLE,
    ZVEC_STATUS_INTERNAL_ERROR,
    ZVEC_STATUS_NOT_SUPPORTED,
    ZVEC_STATUS_UNKNOWN
} zvec_status_code_t;

typedef struct {
    zvec_status_code_t code;
    char message[512];
} zvec_status_t;

// --- Enums ---
typedef enum {
    ZVEC_DATA_TYPE_UNDEFINED = 0,
    ZVEC_DATA_TYPE_BINARY = 1,
    ZVEC_DATA_TYPE_STRING = 2,
    ZVEC_DATA_TYPE_BOOL = 3,
    ZVEC_DATA_TYPE_INT32 = 4,
    ZVEC_DATA_TYPE_INT64 = 5,
    ZVEC_DATA_TYPE_UINT32 = 6,
    ZVEC_DATA_TYPE_UINT64 = 7,
    ZVEC_DATA_TYPE_FLOAT = 8,
    ZVEC_DATA_TYPE_DOUBLE = 9,
    ZVEC_DATA_TYPE_VECTOR_FP32 = 23,
    ZVEC_DATA_TYPE_VECTOR_FP16 = 22,
    ZVEC_DATA_TYPE_VECTOR_INT8 = 26,
} zvec_data_type_t;

typedef enum {
    ZVEC_INDEX_TYPE_UNDEFINED = 0,
    ZVEC_INDEX_TYPE_HNSW = 1,
    ZVEC_INDEX_TYPE_IVF = 3,
    ZVEC_INDEX_TYPE_FLAT = 4,
    ZVEC_INDEX_TYPE_INVERT = 10,
} zvec_index_type_t;

typedef enum {
    ZVEC_METRIC_TYPE_UNDEFINED = 0,
    ZVEC_METRIC_TYPE_L2 = 1,
    ZVEC_METRIC_TYPE_IP = 2,
    ZVEC_METRIC_TYPE_COSINE = 3,
} zvec_metric_type_t;

typedef enum {
    ZVEC_QUANTIZE_TYPE_UNDEFINED = 0,
    ZVEC_QUANTIZE_TYPE_FP16 = 1,
    ZVEC_QUANTIZE_TYPE_INT8 = 2,
    ZVEC_QUANTIZE_TYPE_INT4 = 3,
} zvec_quantize_type_t;

// --- Opaque handles ---
typedef struct zvec_collection_s* zvec_collection_t;
typedef struct zvec_schema_s* zvec_schema_t;
typedef struct zvec_doc_s* zvec_doc_t;

// --- Global init ---
zvec_status_t zvec_init(void);

// --- Schema ---
zvec_schema_t zvec_schema_create(const char* name);
void zvec_schema_destroy(zvec_schema_t schema);
zvec_status_t zvec_schema_add_field(zvec_schema_t schema, const char* name,
                                     zvec_data_type_t data_type, bool nullable);
zvec_status_t zvec_schema_add_vector_field(zvec_schema_t schema, const char* name,
                                            zvec_data_type_t data_type,
                                            uint32_t dimension, bool nullable,
                                            zvec_metric_type_t metric_type);

// --- Collection ---
zvec_status_t zvec_collection_create_and_open(const char* path,
                                               zvec_schema_t schema,
                                               zvec_collection_t* out);
zvec_status_t zvec_collection_open(const char* path, bool read_only,
                                    zvec_collection_t* out);
void zvec_collection_destroy(zvec_collection_t col);
zvec_status_t zvec_collection_flush(zvec_collection_t col);
zvec_status_t zvec_collection_optimize(zvec_collection_t col);
zvec_status_t zvec_collection_delete_by_filter(zvec_collection_t col, const char* filter);
zvec_status_t zvec_collection_destroy_data(zvec_collection_t col);
zvec_status_t zvec_collection_doc_count(zvec_collection_t col, uint64_t* out);

// --- Doc ---
zvec_doc_t zvec_doc_create(const char* pk);
void zvec_doc_destroy(zvec_doc_t doc);
const char* zvec_doc_get_pk(zvec_doc_t doc);
float zvec_doc_get_score(zvec_doc_t doc);

// Doc field setters
zvec_status_t zvec_doc_set_string(zvec_doc_t doc, const char* field, const char* value);
zvec_status_t zvec_doc_set_int32(zvec_doc_t doc, const char* field, int32_t value);
zvec_status_t zvec_doc_set_int64(zvec_doc_t doc, const char* field, int64_t value);
zvec_status_t zvec_doc_set_float(zvec_doc_t doc, const char* field, float value);
zvec_status_t zvec_doc_set_double(zvec_doc_t doc, const char* field, double value);
zvec_status_t zvec_doc_set_bool(zvec_doc_t doc, const char* field, bool value);
zvec_status_t zvec_doc_set_vector_float(zvec_doc_t doc, const char* field,
                                         const float* data, uint32_t dim);

// Doc field setters (unsigned)
zvec_status_t zvec_doc_set_uint32(zvec_doc_t doc, const char* field, uint32_t value);
zvec_status_t zvec_doc_set_uint64(zvec_doc_t doc, const char* field, uint64_t value);

// Doc field getters
zvec_status_t zvec_doc_get_string(zvec_doc_t doc, const char* field, const char** out);
zvec_status_t zvec_doc_get_int32(zvec_doc_t doc, const char* field, int32_t* out);
zvec_status_t zvec_doc_get_int64(zvec_doc_t doc, const char* field, int64_t* out);
zvec_status_t zvec_doc_get_uint32(zvec_doc_t doc, const char* field, uint32_t* out);
zvec_status_t zvec_doc_get_uint64(zvec_doc_t doc, const char* field, uint64_t* out);
zvec_status_t zvec_doc_get_float(zvec_doc_t doc, const char* field, float* out);
zvec_status_t zvec_doc_get_double(zvec_doc_t doc, const char* field, double* out);
zvec_status_t zvec_doc_get_bool(zvec_doc_t doc, const char* field, bool* out);
zvec_status_t zvec_doc_get_vector_float(zvec_doc_t doc, const char* field,
                                         const float** out, uint32_t* dim_out);

// --- Insert / Upsert / Delete ---
zvec_status_t zvec_collection_insert(zvec_collection_t col,
                                      zvec_doc_t* docs, int count);
zvec_status_t zvec_collection_upsert(zvec_collection_t col,
                                      zvec_doc_t* docs, int count);
zvec_status_t zvec_collection_delete(zvec_collection_t col,
                                      const char** pks, int count);

// --- Query ---
zvec_status_t zvec_collection_query(zvec_collection_t col,
                                     const char* field_name,
                                     const float* vector, uint32_t dim,
                                     int topk, const char* filter,
                                     zvec_doc_t** results, int* result_count);

// --- Fetch ---
zvec_status_t zvec_collection_fetch(zvec_collection_t col,
                                     const char** pks, int pk_count,
                                     zvec_doc_t** results, int* result_count);

// --- Index ---
zvec_status_t zvec_collection_create_hnsw_index(zvec_collection_t col,
                                                 const char* field_name,
                                                 zvec_metric_type_t metric,
                                                 int m, int ef_construction);

/// Progress callback type: (current_count, total_count, user_data)
typedef void (*zvec_progress_callback_t)(uint32_t current, uint32_t total, void* user_data);

/// Create an HNSW index with a progress callback
zvec_status_t zvec_collection_create_hnsw_index_with_progress(
    zvec_collection_t col, const char* field_name,
    zvec_metric_type_t metric, int m, int ef_construction,
    zvec_progress_callback_t progress, void* user_data);

zvec_status_t zvec_collection_create_flat_index(zvec_collection_t col,
                                                 const char* field_name,
                                                 zvec_metric_type_t metric);

zvec_status_t zvec_collection_drop_index(zvec_collection_t col,
                                          const char* field_name);

// --- Utility ---
void zvec_free_doc_array(zvec_doc_t* docs, int count);

#ifdef __cplusplus
}
#endif

#endif // ZVEC_C_H

