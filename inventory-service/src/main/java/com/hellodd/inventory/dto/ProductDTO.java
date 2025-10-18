package com.hellodd.inventory.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * Data Transfer Object for Product.
 * Used for API responses to avoid exposing internal entity structure.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ProductDTO {
    private String id;
    private String sku;
    private String name;
    private String description;
    private Integer stockLevel;
    private Integer availableStock;
    private BigDecimal price;
    private Boolean active;
}