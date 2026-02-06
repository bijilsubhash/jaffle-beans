{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is not none and custom_schema_name | trim == 'raw' -%}
        raw
    {%- elif custom_schema_name is not none -%}
        {{ target.schema }}_{{ custom_schema_name | trim }}
    {%- else -%}
        {{ target.schema }}
    {%- endif -%}
{%- endmacro %}
