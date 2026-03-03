#include "include/zvec_c.h"

// The DEBUG macro from Xcode debug builds conflicts with zvec's LogLevel::DEBUG
#ifdef DEBUG
#undef DEBUG
#define ZVEC_HAD_DEBUG 1
#endif

#include <zvec/db/collection.h>
#include <zvec/db/config.h>
#include <zvec/db/doc.h>
#include <zvec/db/index_params.h>
#include <zvec/db/options.h>
#include <zvec/db/schema.h>
#include <zvec/db/stats.h>
#include <zvec/db/status.h>
#include <zvec/db/type.h>

#include <cstring>
#include <memory>
#include <string>
#include <vector>

// --- Internal helpers ---

static zvec_status_t make_status(zvec_status_code_t code, const char* msg) {
    zvec_status_t s;
    s.code = code;
    if (msg) {
        strncpy(s.message, msg, sizeof(s.message) - 1);
        s.message[sizeof(s.message) - 1] = '\0';
    } else {
        s.message[0] = '\0';
    }
    return s;
}

static zvec_status_t ok_status() {
    return make_status(ZVEC_STATUS_OK, "");
}

static zvec_status_t from_cpp_status(const zvec::Status& st) {
    if (st.ok()) return ok_status();
    return make_status(static_cast<zvec_status_code_t>(st.code()), st.c_str());
}

static zvec::DataType to_cpp_data_type(zvec_data_type_t t) {
    return static_cast<zvec::DataType>(t);
}

static zvec::MetricType to_cpp_metric_type(zvec_metric_type_t t) {
    return static_cast<zvec::MetricType>(t);
}

// --- Opaque handle structs ---

struct zvec_schema_s {
    zvec::CollectionSchema schema;
};

struct zvec_collection_s {
    zvec::Collection::Ptr collection;
};

struct zvec_doc_s {
    zvec::Doc doc;
    // Storage for returned strings so pointers remain valid
    std::unordered_map<std::string, std::string> string_cache;
    std::unordered_map<std::string, std::vector<float>> vector_cache;
};

// --- Global init ---

zvec_status_t zvec_init(void) {
    zvec::GlobalConfig::ConfigData config;
    config.log_config = std::make_shared<zvec::GlobalConfig::ConsoleLogConfig>(
        zvec::GlobalConfig::LogLevel::WARN);
    auto st = zvec::GlobalConfig::Instance().Initialize(config);
    return from_cpp_status(st);
}

// --- Schema ---

zvec_schema_t zvec_schema_create(const char* name) {
    auto s = new zvec_schema_s();
    s->schema.set_name(name ? name : "");
    return s;
}

void zvec_schema_destroy(zvec_schema_t schema) {
    delete schema;
}

zvec_status_t zvec_schema_add_field(zvec_schema_t schema, const char* name,
                                     zvec_data_type_t data_type, bool nullable) {
    if (!schema || !name) return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");
    auto field = std::make_shared<zvec::FieldSchema>(name, to_cpp_data_type(data_type), nullable);
    auto st = schema->schema.add_field(field);
    return from_cpp_status(st);
}

zvec_status_t zvec_schema_add_vector_field(zvec_schema_t schema, const char* name,
                                            zvec_data_type_t data_type,
                                            uint32_t dimension, bool nullable,
                                            zvec_metric_type_t metric_type) {
    if (!schema || !name) return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");
    auto index_params = std::make_shared<zvec::FlatIndexParams>(to_cpp_metric_type(metric_type));
    auto field = std::make_shared<zvec::FieldSchema>(name, to_cpp_data_type(data_type),
                                                      dimension, nullable, index_params);
    auto st = schema->schema.add_field(field);
    return from_cpp_status(st);
}

// --- Collection ---

zvec_status_t zvec_collection_create_and_open(const char* path,
                                               zvec_schema_t schema,
                                               zvec_collection_t* out) {
    if (!path || !schema || !out)
        return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");

    zvec::CollectionOptions opts;
    auto result = zvec::Collection::CreateAndOpen(path, schema->schema, opts);
    if (!result.has_value()) {
        return from_cpp_status(result.error());
    }
    auto c = new zvec_collection_s();
    c->collection = result.value();
    *out = c;
    return ok_status();
}

zvec_status_t zvec_collection_open(const char* path, bool read_only,
                                    zvec_collection_t* out) {
    if (!path || !out)
        return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");

    zvec::CollectionOptions opts;
    opts.read_only_ = read_only;
    auto result = zvec::Collection::Open(path, opts);
    if (!result.has_value()) {
        return from_cpp_status(result.error());
    }
    auto c = new zvec_collection_s();
    c->collection = result.value();
    *out = c;
    return ok_status();
}

void zvec_collection_destroy(zvec_collection_t col) {
    delete col;
}

zvec_status_t zvec_collection_flush(zvec_collection_t col) {
    if (!col) return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null collection");
    auto st = col->collection->Flush();
    return from_cpp_status(st);
}

zvec_status_t zvec_collection_optimize(zvec_collection_t col) {
    if (!col) return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null collection");
    auto st = col->collection->Optimize();
    return from_cpp_status(st);
}

zvec_status_t zvec_collection_delete_by_filter(zvec_collection_t col, const char* filter) {
    if (!col || !filter) return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");
    auto st = col->collection->DeleteByFilter(std::string(filter));
    return from_cpp_status(st);
}

zvec_status_t zvec_collection_destroy_data(zvec_collection_t col) {
    if (!col) return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null collection");
    auto st = col->collection->Destroy();
    return from_cpp_status(st);
}

zvec_status_t zvec_collection_doc_count(zvec_collection_t col, uint64_t* out) {
    if (!col || !out) return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");
    auto result = col->collection->Stats();
    if (!result.has_value()) return from_cpp_status(result.error());
    *out = result.value().doc_count;
    return ok_status();
}

// --- Doc ---

zvec_doc_t zvec_doc_create(const char* pk) {
    auto d = new zvec_doc_s();
    if (pk) d->doc.set_pk(pk);
    return d;
}

void zvec_doc_destroy(zvec_doc_t doc) {
    delete doc;
}

const char* zvec_doc_get_pk(zvec_doc_t doc) {
    if (!doc) return nullptr;
    // Cache the pk string so the pointer remains valid
    doc->string_cache["__pk__"] = doc->doc.pk();
    return doc->string_cache["__pk__"].c_str();
}

float zvec_doc_get_score(zvec_doc_t doc) {
    if (!doc) return 0.0f;
    return doc->doc.score();
}

zvec_status_t zvec_doc_set_string(zvec_doc_t doc, const char* field, const char* value) {
    if (!doc || !field) return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");
    doc->doc.set<std::string>(field, value ? value : "");
    return ok_status();
}

zvec_status_t zvec_doc_set_int32(zvec_doc_t doc, const char* field, int32_t value) {
    if (!doc || !field) return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");
    doc->doc.set<int32_t>(field, value);
    return ok_status();
}

zvec_status_t zvec_doc_set_int64(zvec_doc_t doc, const char* field, int64_t value) {
    if (!doc || !field) return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");
    doc->doc.set<int64_t>(field, value);
    return ok_status();
}

zvec_status_t zvec_doc_set_float(zvec_doc_t doc, const char* field, float value) {
    if (!doc || !field) return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");
    doc->doc.set<float>(field, value);
    return ok_status();
}

zvec_status_t zvec_doc_set_double(zvec_doc_t doc, const char* field, double value) {
    if (!doc || !field) return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");
    doc->doc.set<double>(field, value);
    return ok_status();
}

zvec_status_t zvec_doc_set_bool(zvec_doc_t doc, const char* field, bool value) {
    if (!doc || !field) return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");
    doc->doc.set<bool>(field, value);
    return ok_status();
}

zvec_status_t zvec_doc_set_uint32(zvec_doc_t doc, const char* field, uint32_t value) {
    if (!doc || !field) return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");
    doc->doc.set<uint32_t>(field, value);
    return ok_status();
}

zvec_status_t zvec_doc_set_uint64(zvec_doc_t doc, const char* field, uint64_t value) {
    if (!doc || !field) return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");
    doc->doc.set<uint64_t>(field, value);
    return ok_status();
}

zvec_status_t zvec_doc_set_vector_float(zvec_doc_t doc, const char* field,
                                         const float* data, uint32_t dim) {
    if (!doc || !field || !data)
        return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");
    std::vector<float> vec(data, data + dim);
    doc->doc.set<std::vector<float>>(field, std::move(vec));
    return ok_status();
}

zvec_status_t zvec_doc_get_int32(zvec_doc_t doc, const char* field, int32_t* out) {
    if (!doc || !field || !out)
        return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");
    auto result = doc->doc.get<int32_t>(field);
    if (!result.has_value())
        return make_status(ZVEC_STATUS_NOT_FOUND, "field not found");
    *out = result.value();
    return ok_status();
}

zvec_status_t zvec_doc_get_uint32(zvec_doc_t doc, const char* field, uint32_t* out) {
    if (!doc || !field || !out)
        return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");
    auto result = doc->doc.get<uint32_t>(field);
    if (!result.has_value())
        return make_status(ZVEC_STATUS_NOT_FOUND, "field not found");
    *out = result.value();
    return ok_status();
}

zvec_status_t zvec_doc_get_uint64(zvec_doc_t doc, const char* field, uint64_t* out) {
    if (!doc || !field || !out)
        return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");
    auto result = doc->doc.get<uint64_t>(field);
    if (!result.has_value())
        return make_status(ZVEC_STATUS_NOT_FOUND, "field not found");
    *out = result.value();
    return ok_status();
}

zvec_status_t zvec_doc_get_bool(zvec_doc_t doc, const char* field, bool* out) {
    if (!doc || !field || !out)
        return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");
    auto result = doc->doc.get<bool>(field);
    if (!result.has_value())
        return make_status(ZVEC_STATUS_NOT_FOUND, "field not found");
    *out = result.value();
    return ok_status();
}

zvec_status_t zvec_doc_get_string(zvec_doc_t doc, const char* field, const char** out) {
    if (!doc || !field || !out)
        return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");
    auto result = doc->doc.get<std::string>(field);
    if (!result.has_value())
        return make_status(ZVEC_STATUS_NOT_FOUND, "field not found");
    doc->string_cache[field] = result.value();
    *out = doc->string_cache[field].c_str();
    return ok_status();
}

zvec_status_t zvec_doc_get_int64(zvec_doc_t doc, const char* field, int64_t* out) {
    if (!doc || !field || !out)
        return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");
    auto result = doc->doc.get<int64_t>(field);
    if (!result.has_value())
        return make_status(ZVEC_STATUS_NOT_FOUND, "field not found");
    *out = result.value();
    return ok_status();
}

zvec_status_t zvec_doc_get_float(zvec_doc_t doc, const char* field, float* out) {
    if (!doc || !field || !out)
        return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");
    auto result = doc->doc.get<float>(field);
    if (!result.has_value())
        return make_status(ZVEC_STATUS_NOT_FOUND, "field not found");
    *out = result.value();
    return ok_status();
}

zvec_status_t zvec_doc_get_double(zvec_doc_t doc, const char* field, double* out) {
    if (!doc || !field || !out)
        return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");
    auto result = doc->doc.get<double>(field);
    if (!result.has_value())
        return make_status(ZVEC_STATUS_NOT_FOUND, "field not found");
    *out = result.value();
    return ok_status();
}

zvec_status_t zvec_doc_get_vector_float(zvec_doc_t doc, const char* field,
                                         const float** out, uint32_t* dim_out) {
    if (!doc || !field || !out || !dim_out)
        return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");
    auto result = doc->doc.get<std::vector<float>>(field);
    if (!result.has_value())
        return make_status(ZVEC_STATUS_NOT_FOUND, "field not found");
    doc->vector_cache[field] = result.value();
    *out = doc->vector_cache[field].data();
    *dim_out = static_cast<uint32_t>(doc->vector_cache[field].size());
    return ok_status();
}

// --- Insert / Upsert / Delete ---

zvec_status_t zvec_collection_insert(zvec_collection_t col,
                                      zvec_doc_t* docs, int count) {
    if (!col || !docs || count <= 0)
        return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");
    std::vector<zvec::Doc> cpp_docs;
    cpp_docs.reserve(count);
    for (int i = 0; i < count; i++) {
        if (!docs[i]) return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null doc");
        cpp_docs.push_back(docs[i]->doc);
    }
    auto result = col->collection->Insert(cpp_docs);
    if (!result.has_value()) return from_cpp_status(result.error());
    // Check individual write results
    for (auto& ws : result.value()) {
        if (!ws.ok()) return from_cpp_status(ws);
    }
    return ok_status();
}

zvec_status_t zvec_collection_upsert(zvec_collection_t col,
                                      zvec_doc_t* docs, int count) {
    if (!col || !docs || count <= 0)
        return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");
    std::vector<zvec::Doc> cpp_docs;
    cpp_docs.reserve(count);
    for (int i = 0; i < count; i++) {
        if (!docs[i]) return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null doc");
        cpp_docs.push_back(docs[i]->doc);
    }
    auto result = col->collection->Upsert(cpp_docs);
    if (!result.has_value()) return from_cpp_status(result.error());
    for (auto& ws : result.value()) {
        if (!ws.ok()) return from_cpp_status(ws);
    }
    return ok_status();
}

zvec_status_t zvec_collection_delete(zvec_collection_t col,
                                      const char** pks, int count) {
    if (!col || !pks || count <= 0)
        return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");
    std::vector<std::string> pk_vec;
    pk_vec.reserve(count);
    for (int i = 0; i < count; i++) {
        if (!pks[i]) return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null pk");
        pk_vec.emplace_back(pks[i]);
    }
    auto result = col->collection->Delete(pk_vec);
    if (!result.has_value()) return from_cpp_status(result.error());
    return ok_status();
}

// --- Query ---

zvec_status_t zvec_collection_query(zvec_collection_t col,
                                     const char* field_name,
                                     const float* vector, uint32_t dim,
                                     int topk, const char* filter,
                                     zvec_doc_t** results, int* result_count) {
    if (!col || !field_name || !vector || !results || !result_count)
        return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");

    zvec::VectorQuery query;
    query.field_name_ = field_name;
    query.topk_ = topk;
    if (filter) query.filter_ = filter;

    // Convert float array to raw bytes (fp32 vector)
    query.query_vector_ = std::string(reinterpret_cast<const char*>(vector),
                                       dim * sizeof(float));

    auto result = col->collection->Query(query);
    if (!result.has_value()) return from_cpp_status(result.error());

    auto& doc_list = result.value();
    int n = static_cast<int>(doc_list.size());
    *result_count = n;
    if (n == 0) {
        *results = nullptr;
        return ok_status();
    }

    *results = new zvec_doc_t[n];
    for (int i = 0; i < n; i++) {
        if (!doc_list[i]) continue;  // defensive: skip null entries
        auto d = new zvec_doc_s();
        d->doc = *doc_list[i];
        (*results)[i] = d;
    }
    return ok_status();
}

// --- Fetch ---

zvec_status_t zvec_collection_fetch(zvec_collection_t col,
                                     const char** pks, int pk_count,
                                     zvec_doc_t** results, int* result_count) {
    if (!col || !pks || !results || !result_count)
        return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");

    std::vector<std::string> pk_vec;
    pk_vec.reserve(pk_count);
    for (int i = 0; i < pk_count; i++) {
        if (!pks[i]) return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null pk");
        pk_vec.emplace_back(pks[i]);
    }

    auto result = col->collection->Fetch(pk_vec);
    if (!result.has_value()) return from_cpp_status(result.error());

    auto& doc_map = result.value();
    // Count only non-null results (null = not found or deleted)
    int n = 0;
    for (auto& [pk, doc_ptr] : doc_map) {
        if (doc_ptr) n++;
    }
    *result_count = n;
    if (n == 0) {
        *results = nullptr;
        return ok_status();
    }

    *results = new zvec_doc_t[n];
    int idx = 0;
    for (auto& [pk, doc_ptr] : doc_map) {
        if (!doc_ptr) continue;
        auto d = new zvec_doc_s();
        d->doc = *doc_ptr;
        (*results)[idx++] = d;
    }
    return ok_status();
}

// --- Index ---

zvec_status_t zvec_collection_create_hnsw_index(zvec_collection_t col,
                                                 const char* field_name,
                                                 zvec_metric_type_t metric,
                                                 int m, int ef_construction) {
    if (!col || !field_name)
        return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");
    auto params = std::make_shared<zvec::HnswIndexParams>(
        to_cpp_metric_type(metric), m, ef_construction);
    auto st = col->collection->CreateIndex(field_name, params);
    return from_cpp_status(st);
}

zvec_status_t zvec_collection_create_hnsw_index_with_progress(
    zvec_collection_t col, const char* field_name,
    zvec_metric_type_t metric, int m, int ef_construction,
    zvec_progress_callback_t progress, void* user_data) {
    if (!col || !field_name)
        return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");
    auto params = std::make_shared<zvec::HnswIndexParams>(
        to_cpp_metric_type(metric), m, ef_construction);
    zvec::CreateIndexOptions options;
    if (progress) {
        options.progress_callback_ = [progress, user_data](uint32_t current, uint32_t total) {
            progress(current, total, user_data);
        };
    }
    auto st = col->collection->CreateIndex(field_name, params, options);
    return from_cpp_status(st);
}

zvec_status_t zvec_collection_create_flat_index(zvec_collection_t col,
                                                 const char* field_name,
                                                 zvec_metric_type_t metric) {
    if (!col || !field_name)
        return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");
    auto params = std::make_shared<zvec::FlatIndexParams>(to_cpp_metric_type(metric));
    auto st = col->collection->CreateIndex(field_name, params);
    return from_cpp_status(st);
}

zvec_status_t zvec_collection_drop_index(zvec_collection_t col,
                                          const char* field_name) {
    if (!col || !field_name)
        return make_status(ZVEC_STATUS_INVALID_ARGUMENT, "null argument");
    auto st = col->collection->DropIndex(field_name);
    return from_cpp_status(st);
}

// --- Utility ---

void zvec_free_doc_array(zvec_doc_t* docs, int count) {
    if (!docs) return;
    for (int i = 0; i < count; i++) {
        delete docs[i];
    }
    delete[] docs;
}
