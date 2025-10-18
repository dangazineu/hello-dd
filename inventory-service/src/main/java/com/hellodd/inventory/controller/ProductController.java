package com.hellodd.inventory.controller;

import com.hellodd.inventory.dto.ProductDTO;
import com.hellodd.inventory.dto.StockUpdateRequest;
import com.hellodd.inventory.model.Product;
import com.hellodd.inventory.service.ProductService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * REST controller for Product operations.
 * Provides endpoints for inventory management and product queries.
 */
@RestController
@RequestMapping("/api/v1/products")
@RequiredArgsConstructor
@Slf4j
public class ProductController {

    private final ProductService productService;

    /**
     * Get all products
     */
    @GetMapping
    public ResponseEntity<List<ProductDTO>> getAllProducts(
            @RequestParam(required = false, defaultValue = "false") boolean inStockOnly) {
        log.info("Fetching products - inStockOnly: {}", inStockOnly);

        List<Product> products = inStockOnly
            ? productService.getInStockProducts()
            : productService.getAllProducts();

        List<ProductDTO> productDTOs = products.stream()
            .map(this::convertToDTO)
            .collect(Collectors.toList());

        return ResponseEntity.ok(productDTOs);
    }

    /**
     * Get a product by ID
     */
    @GetMapping("/{id}")
    public ResponseEntity<ProductDTO> getProductById(@PathVariable String id) {
        log.info("Fetching product by ID: {}", id);

        return productService.getProductById(id)
            .map(this::convertToDTO)
            .map(ResponseEntity::ok)
            .orElse(ResponseEntity.notFound().build());
    }

    /**
     * Get a product by SKU
     */
    @GetMapping("/sku/{sku}")
    public ResponseEntity<ProductDTO> getProductBySku(@PathVariable String sku) {
        log.info("Fetching product by SKU: {}", sku);

        return productService.getProductBySku(sku)
            .map(this::convertToDTO)
            .map(ResponseEntity::ok)
            .orElse(ResponseEntity.notFound().build());
    }

    /**
     * Check stock availability for a product
     */
    @GetMapping("/{id}/stock")
    public ResponseEntity<Map<String, Object>> checkStock(@PathVariable String id) {
        log.info("Checking stock for product: {}", id);

        return productService.getProductById(id)
            .map(product -> {
                Map<String, Object> stockInfo = Map.of(
                    "productId", product.getId(),
                    "sku", product.getSku(),
                    "stockLevel", product.getStockLevel(),
                    "reservedStock", product.getReservedStock(),
                    "availableStock", product.getAvailableStock(),
                    "inStock", product.isInStock()
                );
                return ResponseEntity.ok(stockInfo);
            })
            .orElse(ResponseEntity.notFound().build());
    }

    /**
     * Update stock level for a product (for demo purposes)
     */
    @PutMapping("/{id}/stock")
    public ResponseEntity<ProductDTO> updateStock(
            @PathVariable String id,
            @RequestBody StockUpdateRequest request) {
        log.info("Updating stock for product {}: {}", id, request);

        try {
            Product updated = productService.updateStock(id, request);
            return ResponseEntity.ok(convertToDTO(updated));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().build();
        }
    }

    /**
     * Get low stock products
     */
    @GetMapping("/low-stock")
    public ResponseEntity<List<ProductDTO>> getLowStockProducts(
            @RequestParam(defaultValue = "10") Integer threshold) {
        log.info("Fetching low stock products with threshold: {}", threshold);

        List<ProductDTO> products = productService.getLowStockProducts(threshold)
            .stream()
            .map(this::convertToDTO)
            .collect(Collectors.toList());

        return ResponseEntity.ok(products);
    }

    /**
     * Health check endpoint
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Map.of(
            "status", "UP",
            "service", "inventory-service",
            "version", "1.0.0"
        ));
    }

    /**
     * Convert Product entity to DTO
     */
    private ProductDTO convertToDTO(Product product) {
        return ProductDTO.builder()
            .id(product.getId())
            .sku(product.getSku())
            .name(product.getName())
            .description(product.getDescription())
            .stockLevel(product.getStockLevel())
            .availableStock(product.getAvailableStock())
            .price(product.getPrice())
            .active(product.getActive())
            .build();
    }
}