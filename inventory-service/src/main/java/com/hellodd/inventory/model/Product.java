package com.hellodd.inventory.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * Product entity representing an item in inventory.
 * This is a simplified model for demonstration purposes.
 */
@Entity
@Table(name = "products")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Product {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private String id;

    @Column(nullable = false, unique = true)
    private String sku;

    @Column(nullable = false)
    private String name;

    @Column(length = 1000)
    private String description;

    @Column(name = "stock_level", nullable = false)
    private Integer stockLevel = 0;

    @Column(nullable = false)
    private BigDecimal price;

    @Column(name = "reserved_stock")
    private Integer reservedStock = 0;

    @Column(name = "is_active")
    private Boolean active = true;

    /**
     * Get available stock (total stock minus reserved)
     */
    public Integer getAvailableStock() {
        return Math.max(0, stockLevel - reservedStock);
    }

    /**
     * Check if product is in stock
     */
    public boolean isInStock() {
        return getAvailableStock() > 0;
    }
}