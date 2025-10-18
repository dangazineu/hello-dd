package com.hellodd.inventory.repository;

import com.hellodd.inventory.model.Product;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * Repository for Product entity.
 * Provides basic CRUD operations and custom queries for inventory management.
 */
@Repository
public interface ProductRepository extends JpaRepository<Product, String> {

    /**
     * Find a product by its SKU
     */
    Optional<Product> findBySku(String sku);

    /**
     * Find all active products
     */
    List<Product> findByActiveTrue();

    /**
     * Find products with stock level below a threshold
     */
    @Query("SELECT p FROM Product p WHERE p.stockLevel <= :threshold AND p.active = true")
    List<Product> findLowStockProducts(@Param("threshold") Integer threshold);

    /**
     * Find products that are in stock
     */
    @Query("SELECT p FROM Product p WHERE p.stockLevel > p.reservedStock AND p.active = true")
    List<Product> findInStockProducts();

    /**
     * Check if a product exists by SKU
     */
    boolean existsBySku(String sku);
}